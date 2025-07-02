# ===================================================================
#  PHASE 3: DEPLOY K3S CLUSTER FROM GOLDEN IMAGE
# ===================================================================

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
  }
}

variable "pm_api_token" {
  description = "The API token for the Proxmox provider."
  sensitive   = true
}

provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = var.pm_api_token
}

# --- Define the VMs we want to create ---
locals {
  vms_to_create = {
    "dev-k3s-master-01" = { node = "pve1", vmid = 801, ip = "192.168.1.81/24" },
    "dev-k3s-worker-01" = { node = "pve2", vmid = 802, ip = "192.168.1.82/24" }
  }
}

# --- Provision the VMs by cloning the golden template ---
resource "proxmox_virtual_environment_vm" "web_servers" {
  for_each = local.vms_to_create

  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vmid
  tags      = ["k3s", "golden-image"]

  # THE MAGIC: Clone the finished template. Fast, simple, reliable.
  clone {
    vm_id = 9000 # The ID of the template Packer built for us.
    full  = true 
  }

  cpu { cores = 6 }
  memory { dedicated = 8192 }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  # The golden image already has a disk, we're just resizing it.
  disk {
    datastore_id = "cluster-shared-nfs"
    interface    = "scsi0"
    size         = 20
  }

  # We only need cloud-init to set the unique IP address.
  # All packages and software are already baked into the golden image.
  initialization {
    ip_config {
      ipv4 {
        address = each.value.ip
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- Output the IP addresses of the new VMs ---
output "web_server_ips" {
  description = "The IP addresses of the created k3s servers."
  value       = { for vm in proxmox_virtual_environment_vm.web_servers : vm.name => vm.initialization[0].ip_config[0].ipv4[0].address }
}
