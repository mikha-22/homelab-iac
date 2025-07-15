# ===================================================================
#  PROJECT: NAS VIRTUAL MACHINE (SECURE & CORRECTED VERSION)
#  Provisions the NFS server VM by fetching all credentials from
#  Google Secret Manager and correctly handling destroy-time cleanup.
# ===================================================================

# --- DATA SOURCE TO LINK PROJECTS ---
data "terraform_remote_state" "images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "02_create_nas/01_base_images"
  }
}

# --- DATA SOURCES FOR SECRETS ---
# Note: These are required by the provider configurations in providers.tf
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}
data "google_secret_manager_secret_version" "pm_ssh_password" {
  secret = "proxmox-ssh-password"
}
data "google_secret_manager_secret_version" "nas_ssh_key" {
  secret  = "nas-vm-ssh-key"
}

# --- RENDER THE CLOUD-INIT FILE AS A TEMPLATE ---
locals {
  nas_cloud_init_content = templatefile("${path.module}/nas-cloud-init.yaml", {
    ssh_public_key = trimspace(data.google_secret_manager_secret_version.nas_ssh_key.secret_data)
  })
}

# --- CLOUD-INIT SNIPPET RESOURCE ---
resource "proxmox_virtual_environment_file" "nas_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    file_name = "nas-cloud-init-rendered.yaml"
    data      = local.nas_cloud_init_content
  }
}

# --- NAS VIRTUAL MACHINE ---
resource "proxmox_virtual_environment_vm" "nfs_server" {
  name        = "nfs-server-01"
  description = "NFS server for Proxmox cluster shared storage"
  tags        = ["nas", "nfs", "infra"]
  node_name   = "pve1"
  vm_id       = 225

  depends_on = [
    proxmox_virtual_environment_file.nas_cloud_init
  ]
  
  cpu { cores = 1 }
  memory { dedicated = 2048 }
  
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }
  
  boot_order = ["scsi0"]
  
  agent {
    enabled = true
    trim    = true
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 50
    file_id      = data.terraform_remote_state.images.outputs.ubuntu_image_id
    discard      = "on"
  }

  on_boot = true

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.nas_cloud_init.id
    dns { servers = ["1.1.1.1", "8.8.8.8"] }
    ip_config {
      ipv4 {
        address = "192.168.1.225/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- REGISTER THE NFS STORAGE IN PROXMOX ---
resource "null_resource" "register_nfs_storage" {
  depends_on = [proxmox_virtual_environment_vm.nfs_server]

  triggers = {
    vm_id = proxmox_virtual_environment_vm.nfs_server.id
    
    # Store the password in the triggers map so it's available at destroy time.
    # The sensitive() function prevents it from being shown in CLI output.
    proxmox_password = sensitive(trimspace(data.google_secret_manager_secret_version.pm_ssh_password.secret_data))
  }

  # Give the VM time to boot and for the NFS server to start.
  provisioner "local-exec" {
    command = "echo 'Waiting 20 seconds for VM to boot and NFS to start...' && sleep 20"
  }

  # Create-time provisioner uses self.triggers.
  provisioner "local-exec" {
    environment = {
      PROXMOX_PASSWORD = self.triggers.proxmox_password
    }
    command = <<-EOT
      for node in pve1.local pve2.local; do
        sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$node" "mkdir -p /mnt/pve/cluster-shared-nfs"
      done && \
      sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm add nfs cluster-shared-nfs --path /mnt/pve/cluster-shared-nfs --server 192.168.1.225 --export /export/proxmox-storage --content images,iso,vztmpl,snippets,backup,rootdir --nodes pve1,pve2"
    EOT
  }

  # Destroy-time provisioner now correctly references its own trigger value.
  provisioner "local-exec" {
    when = destroy
    environment = {
      # This is now a valid reference during the destroy phase.
      PROXMOX_PASSWORD = self.triggers.proxmox_password
    }
    command = <<-EOT
      sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "if pvesm status | grep -q '^cluster-shared-nfs '; then pvesm remove cluster-shared-nfs; fi" && \
      for node in pve1.local pve2.local; do
        sshpass -p "$PROXMOX_PASSWORD" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$node" "umount -l /mnt/pve/cluster-shared-nfs || true; rmdir /mnt/pve/cluster-shared-nfs || true"
      done
    EOT
  }
}
