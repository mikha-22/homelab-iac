# ===================================================================
#  PHASE 1: CREATE BASE TEMPLATE ON SHARED STORAGE
# ===================================================================

module "shared" {
  source = "../../shared"
}

data "terraform_remote_state" "base_images" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_nas/01_base_images"
  }
}

locals {
  base_template_init_content = templatefile("${path.module}/base-template-init.yaml", {
    user_ssh_public_key = module.shared.nas_ssh_public_key
  })
}

resource "proxmox_virtual_environment_file" "base_template_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "base-template-init.yaml"
    data      = local.base_template_init_content
  }
}

resource "proxmox_virtual_environment_vm" "base_cloud_template" {
  name        = "ubuntu-2404-cloud-base"
  description = "Base cloud-image template on shared storage"
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
    datastore_id = "cluster-shared-nfs"
    interface    = "scsi0"
    size         = 10
    file_id      = data.terraform_remote_state.base_images.outputs.ubuntu_image.id
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
