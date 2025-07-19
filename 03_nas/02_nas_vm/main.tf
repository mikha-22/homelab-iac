# ===================================================================
#  NAS VM - CLEAN CONFIGURATION
# ===================================================================

module "shared" {
  source = "../../shared"
}

data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_private_key" {
  secret = "proxmox-ssh-private-key"
}

data "terraform_remote_state" "images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_nas/01_base_images"
  }
}

locals {
  nas_cloud_init_content = templatefile("${path.module}/nas-cloud-init.yaml", {
    ssh_public_key = module.shared.nas_ssh_public_key
  })
}

resource "proxmox_virtual_environment_file" "nas_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    file_name = "nas-cloud-init-rendered.yaml"
    data      = local.nas_cloud_init_content
  }
}

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
    file_id      = data.terraform_remote_state.images.outputs.ubuntu_image.id
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

resource "null_resource" "register_nfs_storage" {
  depends_on = [proxmox_virtual_environment_vm.nfs_server]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.nfs_server.id
    nas_ip = module.shared.network.nas_server
    proxmox_ssh_key = sensitive(trimspace(data.google_secret_manager_secret_version.pm_ssh_private_key.secret_data))
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Waiting for NAS VM to boot and NFS service to start..."
      timeout 120 bash -c '
        while ! ping -c 1 ${module.shared.network.nas_server} >/dev/null 2>&1; do 
          echo "  Waiting for ${module.shared.network.nas_server}..."
          sleep 5
        done
      '
      
      echo "Waiting additional 30 seconds for NFS service to be ready..."
      sleep 30
      
      echo "NAS VM is ready at ${module.shared.network.nas_server}"
    EOT
  }

  provisioner "local-exec" {
    environment = {
      SSH_KEY_CONTENT = self.triggers.proxmox_ssh_key
    }
    command = <<-EOT
      echo "Registering NFS storage in Proxmox cluster..."
      
      TMP_KEY=$(mktemp)
      echo "$SSH_KEY_CONTENT" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      for node in pve1.local pve2.local; do
        echo "  Creating mount point on $node..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@$node" \
          "mkdir -p /mnt/pve/cluster-shared-nfs" || echo "  Mount point already exists on $node"
      done
      
      echo "  Adding NFS storage configuration..."
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@pve1.local" \
        "pvesm add nfs cluster-shared-nfs --path /mnt/pve/cluster-shared-nfs --server ${module.shared.network.nas_server} --export /export/proxmox-storage --content images,iso,vztmpl,snippets,backup,rootdir --nodes pve1,pve2" || echo "  NFS storage already exists"
      
      rm -f "$TMP_KEY"
      
      echo "NFS storage 'cluster-shared-nfs' registered successfully"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    environment = {
      SSH_KEY_CONTENT = self.triggers.proxmox_ssh_key
    }
    command = <<-EOT
      echo "Removing NFS storage from Proxmox cluster..."
      
      TMP_KEY=$(mktemp)
      echo "$SSH_KEY_CONTENT" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@pve1.local" \
        "if pvesm status | grep -q '^cluster-shared-nfs '; then pvesm remove cluster-shared-nfs; fi" || echo "  NFS storage already removed"
      
      for node in pve1.local pve2.local; do
        echo "  Cleaning up mount point on $node..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" "root@$node" \
          "umount -l /mnt/pve/cluster-shared-nfs 2>/dev/null || true; rmdir /mnt/pve/cluster-shared-nfs 2>/dev/null || true" || echo "  Cleanup completed on $node"
      done
      
      rm -f "$TMP_KEY"
      
      echo "NFS storage cleanup completed"
    EOT
  }
}

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
      echo "Verifying NAS connectivity and NFS exports..."
      
      echo "Testing NFS exports..."
      timeout 60 bash -c '
        while ! showmount -e ${module.shared.network.nas_server} >/dev/null 2>&1; do
          echo "  Waiting for NFS exports..."
          sleep 5
        done
      '
      
      echo "NFS exports are available:"
      showmount -e ${module.shared.network.nas_server}
      
      echo "NAS VM and storage registration complete"
    EOT
  }
}
