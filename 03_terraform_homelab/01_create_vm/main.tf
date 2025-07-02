# ===================================================================
#  PHASE 3: DEPLOY K3S CLUSTER FROM GOLDEN IMAGE - FINAL WORKING VERSION
#  Uses separate resources instead of for_each to avoid provider issues
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

# --- Master VM (separate resource) ---
resource "proxmox_virtual_environment_vm" "master" {
  name      = "dev-k3s-master-01"
  node_name = "pve1"
  vm_id     = 801
  tags      = ["k3s", "golden-image"]

  clone {
    vm_id = 9000
    full  = true 
  }

  cpu { cores = 6 }
  memory { dedicated = 8192 }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.81/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- Worker VM (separate resource) ---
resource "proxmox_virtual_environment_vm" "worker" {
  name      = "dev-k3s-worker-01"
  node_name = "pve2"
  vm_id     = 802
  tags      = ["k3s", "golden-image"]

  clone {
    vm_id = 9010
    full  = true 
  }

  cpu { cores = 6 }
  memory { dedicated = 8192 }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    ip_config {
      ipv4 {
        address = "192.168.1.82/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- Outputs ---
output "web_server_ips" {
  description = "The IP addresses of the created k3s servers."
  value = {
    "dev-k3s-master-01" = proxmox_virtual_environment_vm.master.initialization[0].ip_config[0].ipv4[0].address
    "dev-k3s-worker-01" = proxmox_virtual_environment_vm.worker.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "cluster_info" {
  description = "K3s cluster information for next steps"
  value = {
    master = {
      name = "dev-k3s-master-01"
      ip   = "192.168.1.81"
      node = "pve1"
      vmid = 801
    }
    workers = [
      {
        name = "dev-k3s-worker-01"
        ip   = "192.168.1.82"
        node = "pve2"
        vmid = 802
      }
    ]
    ssh_command = "ssh ubuntu@192.168.1.81  # Connect to master node"
  }
}
