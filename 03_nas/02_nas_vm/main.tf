# ===================================================================
#  NAS VM - USING SHARED CONFIGURATION WITH AUTOMATIC STORAGE REGISTRATION
#  FIXED: Now includes all required data sources and storage registration
# ===================================================================

# --- IMPORT SHARED MODULE ---
module "shared" {
  source = "../../shared"
}

# --- DATA SOURCES FOR AUTHENTICATION (REQUIRED BY PROVIDERS) ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_private_key" {
  secret = "proxmox-ssh-private-key"
}

# --- GET BASE IMAGE ---
data "terraform_remote_state" "images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_nas/01_base_images"
  }
}

# --- CLOUD-INIT TEMPLATE ---
locals {
  nas_cloud_init_content = templatefile("${path.module}/nas-cloud-init.yaml", {
    ssh_public_key = module.shared.nas_ssh_public_key
  })
}

# --- CLOUD-INIT FILE ---
resource "proxmox_virtual_environment_file" "nas_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    file_name = "nas-cloud-init-rendered.yaml"
    data      = local.nas_cloud_init_content
  }
}

# --- NAS VM ---
resource "proxmox_virtual_environment_vm" "nfs_server" {
  name        = "nfs-server-01"
  description = "NFS server for Proxmox cluster shared storage"
  tags        = concat(module.shared.common_tags, module.shared.role_tags.nas)
  node_name   = "pve1"
  vm_id       = module.shared.vm_ids.nas_server

  depends_on = [proxmox_virtual_environment_file.nas_cloud_init]
  
  cpu { 
    cores = module.shared.vm_configs.nas.cores
  }
  memory { 
    dedicated = module.shared.vm_configs.nas.memory
  }
  
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  boot_order = ["scsi0"]
  
  agent { 
    enabled = true 
    trim = true 
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = module.shared.vm_configs.nas.disk
    file_id      = data.terraform_remote_state.images.outputs.ubuntu_image_id
    discard      = "on"
  }

  on_boot = true

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.nas_cloud_init.id
    dns { 
      servers = module.shared.dns_servers
    }
    ip_config {
      ipv4 {
        address = module.shared.full_ips.nas_server
        gateway = module.shared.gateway
      }
    }
  }
}

# --- REGISTER THE NFS STORAGE IN PROXMOX (RESTORED FROM OLD CODE) ---
resource "null_resource" "register_nfs_storage" {
  depends_on = [proxmox_virtual_environment_vm.nfs_server]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.nfs_server.id
    nas_ip = module.shared.network.nas_server
    # Store SSH private key in triggers for destroy-time access
    proxmox_ssh_key = sensitive(trimspace(data.google_secret_manager_secret_version.pm_ssh_private_key.secret_data))
  }

  # Wait for VM to boot and NFS to start
  provisioner "local-exec" {
    command = <<-EOT
      echo "⏳ Waiting for NAS VM to boot and NFS service to start..."
      timeout 120 bash -c '
        while ! ping -c 1 ${module.shared.network.nas_server} >/dev/null 2>&1; do 
          echo "  Waiting for ${module.shared.network.nas_server}..."
          sleep 5
        done
      '
      
      echo "⏳ Waiting additional 30 seconds for NFS service to be ready..."
      sleep 30
      
      echo "✅ NAS VM is ready at ${module.shared.network.nas_server}"
    EOT
  }

  # Register NFS storage in Proxmox cluster using SSH key from Secret Manager
  provisioner "local-exec" {
    environment = {
      SSH_KEY_CONTENT = self.triggers.proxmox_ssh_key
    }
    command = <<-EOT
      echo "🔧 Registering NFS storage in Proxmox cluster..."
      
      # Create temporary SSH key file
      TMP_KEY=$(mktemp)
      echo "$SSH_KEY_CONTENT" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      # Create mount points on both nodes
      for node in pve1.local pve2.local; do
        echo "  Creating mount point on $node..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@$node" \
          "mkdir -p /mnt/pve/cluster-shared-nfs" || echo "  Mount point already exists on $node"
      done
      
      # Add NFS storage to Proxmox
      echo "  Adding NFS storage configuration..."
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@pve1.local" \
        "pvesm add nfs cluster-shared-nfs --path /mnt/pve/cluster-shared-nfs --server ${module.shared.network.nas_server} --export /export/proxmox-storage --content images,iso,vztmpl,snippets,backup,rootdir --nodes pve1,pve2" || echo "  NFS storage already exists"
      
      # Clean up temporary key file
      rm -f "$TMP_KEY"
      
      echo "✅ NFS storage 'cluster-shared-nfs' registered successfully"
    EOT
  }

  # Cleanup NFS storage on destroy
  provisioner "local-exec" {
    when = destroy
    environment = {
      SSH_KEY_CONTENT = self.triggers.proxmox_ssh_key
    }
    command = <<-EOT
      echo "🧹 Removing NFS storage from Proxmox cluster..."
      
      # Create temporary SSH key file
      TMP_KEY=$(mktemp)
      echo "$SSH_KEY_CONTENT" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      # Remove NFS storage configuration
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@pve1.local" \
        "if pvesm status | grep -q '^cluster-shared-nfs '; then pvesm remove cluster-shared-nfs; fi" || echo "  NFS storage already removed"
      
      # Unmount and remove mount points
      for node in pve1.local pve2.local; do
        echo "  Cleaning up mount point on $node..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@$node" \
          "umount -l /mnt/pve/cluster-shared-nfs 2>/dev/null || true; rmdir /mnt/pve/cluster-shared-nfs 2>/dev/null || true" || echo "  Cleanup completed on $node"
      done
      
      # Clean up temporary key file
      rm -f "$TMP_KEY"
      
      echo "✅ NFS storage cleanup completed"
    EOT
  }
}

# --- CONNECTIVITY VERIFICATION ---
resource "null_resource" "verify_nas_connectivity" {
  depends_on = [
    proxmox_virtual_environment_vm.nfs_server,
    null_resource.register_nfs_storage
  ]

  triggers = {
    vm_id     = proxmox_virtual_environment_vm.nfs_server.id
    nas_ip    = module.shared.network.nas_server
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Verifying NAS connectivity and NFS exports..."
      
      # Test NFS exports are available
      echo "⏳ Testing NFS exports..."
      timeout 60 bash -c '
        while ! showmount -e ${module.shared.network.nas_server} >/dev/null 2>&1; do
          echo "  Waiting for NFS exports..."
          sleep 5
        done
      '
      
      echo "✅ NFS exports are available:"
      showmount -e ${module.shared.network.nas_server}
      
      echo "🎉 NAS VM and storage registration complete!"
    EOT
  }
}
