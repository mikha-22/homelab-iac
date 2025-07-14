# ===================================================================
#  PHASE 3: DEPLOY K3S CLUSTER FROM GOLDEN IMAGE - SECURE VERSION
#  Fetches all secrets from Google Secret Manager and uses templates
#  for cloud-init configuration.
# ===================================================================

# --- GOOGLE PROVIDER CONFIGURATION ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- DATA SOURCES FOR SECRETS ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}
data "google_secret_manager_secret_version" "pm_ssh_password" {
  secret = "proxmox-ssh-password"
}
# Fetch the general user SSH key for node access.
data "google_secret_manager_secret_version" "user_ssh_key" {
  secret = "nas-vm-ssh-key"
}

# --- PROXMOX PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
  
  ssh {
    username = "root"
    password = trimspace(data.google_secret_manager_secret_version.pm_ssh_password.secret_data)
  }
}

# --- RENDER CLOUD-INIT TEMPLATES ---
locals {
  master_init_content = templatefile("${path.module}/master-init.yaml", {
    user_ssh_public_key = trimspace(data.google_secret_manager_secret_version.user_ssh_key.secret_data)
  })
  worker_init_content = templatefile("${path.module}/worker-init.yaml", {
    user_ssh_public_key = trimspace(data.google_secret_manager_secret_version.user_ssh_key.secret_data)
  })
}

# --- UPLOAD RENDERED CLOUD-INIT FILES ---
resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "master-hostname-init.yaml"
    data      = local.master_init_content
  }
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve2" # Assuming worker is on pve2 for cloud-init storage

  source_raw {
    file_name = "worker-hostname-init.yaml"
    data      = local.worker_init_content
  }
}

# --- MASTER VM ---
resource "proxmox_virtual_environment_vm" "master" {
  name      = "dev-k3s-master-01"
  node_name = "pve1"
  vm_id     = 181
  tags      = ["k3s", "golden-image"]

  depends_on = [proxmox_virtual_environment_file.master_cloud_init]

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
    user_data_file_id = proxmox_virtual_environment_file.master_cloud_init.id
    ip_config {
      ipv4 {
        address = "192.168.1.181/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- WORKER VM ---
resource "proxmox_virtual_environment_vm" "worker" {
  name      = "dev-k3s-worker-01"
  node_name = "pve2"
  vm_id     = 182
  tags      = ["k3s", "golden-image"]

  depends_on = [proxmox_virtual_environment_file.worker_cloud_init]

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
    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init.id
    ip_config {
      ipv4 {
        address = "192.168.1.182/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- OUTPUTS ---
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
      name     = "dev-k3s-master-01"
      hostname = "dev-k3s-master-01"
      ip       = "192.168.1.181"
      node     = "pve1"
      vmid     = 181
    }
    workers = [
      {
        name     = "dev-k3s-worker-01"
        hostname = "dev-k3s-worker-01"
        ip       = "192.168.1.182"
        node     = "pve2"
        vmid     = 182
      }
    ]
    ssh_command = "ssh ubuntu@192.168.1.181  # Connect to master node"
  }
}
