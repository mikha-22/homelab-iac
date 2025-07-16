# ===================================================================
#  PHASE 1: CREATE BASE TEMPLATE - USING CENTRALIZED PROVIDERS
#  Creates cloud-init file on SHARED storage for cross-node access
#  Uses direct template creation instead of Packer builds
# ===================================================================

# --- IMPORT SHARED MODULE (FIXED PATH) ---
module "shared" {
  source = "../../shared"  # Fixed: was ../../../shared
}

# --- DATA SOURCE TO GET BASE IMAGE ID ---
data "terraform_remote_state" "base_images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_nas/01_base_images"
  }
}

# --- RENDER THE CLOUD-INIT FILE AS A TEMPLATE ---
locals {
  base_template_init_content = templatefile("${path.module}/base-template-init.yaml", {
    user_ssh_public_key = module.shared.nas_ssh_public_key
  })
}

# --- CREATE CLOUD-INIT FILE ON SHARED STORAGE ---
resource "proxmox_virtual_environment_file" "base_template_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "base-template-init.yaml"
    data      = local.base_template_init_content
  }
}

# --- BASE VM TEMPLATE (NO PACKER NEEDED) ---
resource "proxmox_virtual_environment_vm" "base_cloud_template" {
  name        = "ubuntu-2404-cloud-base"
  description = "Base cloud-image template for VM deployment - no Packer needed!"
  node_name   = "pve1"
  vm_id       = 9999
  template    = true

  depends_on = [
    proxmox_virtual_environment_file.base_template_init
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
    user_data_file_id = proxmox_virtual_environment_file.base_template_init.id
    datastore_id      = "cluster-shared-nfs"
    dns {
      servers = module.shared.dns_servers
    }
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }
}
