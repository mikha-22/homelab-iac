# ===================================================================
#  PHASE 1: BOOTSTRAP PACKER BASE TEMPLATE - FIXED VERSION
#  Creates cloud-init file on SHARED storage for cross-node access
# ===================================================================

# --- DATA SOURCES FOR SECRETS ---
# Note: These are required by the provider configurations in providers.tf
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}
data "google_secret_manager_secret_version" "pm_ssh_password" {
  secret = "proxmox-ssh-password"
}

# --- DATA SOURCE TO GET BASE IMAGE ID ---
data "terraform_remote_state" "base_images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "02_create_nas/01_base_images"
  }
}

# --- CREATE CLOUD-INIT FILE ON SHARED STORAGE ---
resource "proxmox_virtual_environment_file" "packer_auth_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "packer-auth-init.yaml"
    data      = file("${path.module}/packer-auth-init.yaml")
  }
}

# --- BASE VM TEMPLATE FOR PACKER ---
resource "proxmox_virtual_environment_vm" "base_cloud_template" {
  name        = "ubuntu-2404-cloud-base"
  description = "DO NOT DELETE: Base cloud-image template for Packer."
  node_name   = "pve1"
  vm_id       = 9999
  template    = true

  depends_on = [
    proxmox_virtual_environment_file.packer_auth_init
  ]

  agent { enabled = true }
  cpu { cores = 1 }
  memory { dedicated = 2048 }
  scsi_hardware = "virtio-scsi-pci"
  boot_order    = ["scsi0"]

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 10
    file_id      = data.terraform_remote_state.base_images.outputs.ubuntu_image_id
  }
  
  initialization {
    user_data_file_id = proxmox_virtual_environment_file.packer_auth_init.id
    datastore_id      = "cluster-shared-nfs"
    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
