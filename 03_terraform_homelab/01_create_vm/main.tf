# ===================================================================
#  PHASE 3: DEPLOY K3S CLUSTER FROM GOLDEN IMAGE - WITH UNIQUE HOSTNAMES
#  Fixed to set unique hostnames via cloud-init
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

variable "pm_ssh_password" {
  description = "The SSH password for the Proxmox nodes."
  sensitive   = true
}

provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = var.pm_api_token
  
  ssh {
    username = "root"
    password = var.pm_ssh_password
  }
}

# --- Cloud-init files for setting unique hostnames ---
resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "master-hostname-init.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: dev-k3s-master-01
      manage_etc_hosts: true
      
      # Preserve existing SSH keys
      ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSo7JnBBuSGhZp1EBI1D3zqAV5Y/zSr70LU21JYALlhv68W8wrMDQxn4KphXh2URGuYmCAF5/gyeV49Sinl0SbNErCqQGMPQlEYYm9eru+svEtaDhH5xuJYVzqoSTsS6iDsTp/kHASbnFb9lSAa0jo8RaXSbtzUHPL7lpO+YdVbKEJq0MK9B4dkNWsOHOnjFKJ35cL2u8h2SPHOZO7k7w3maPaDGrXaalv8skvfgPhrJ8zPwgs/r5g6X+LCl4LgVq4RZs9ssg+m389t4ezGoHyyfBqOzTgptugxb8Oq6Ml0nMe6f7sCudpYRc+/wwstCzarvowyPv5Cc9ZmnQOpuxAmU+GSR61T0+rZXtbcjwZVDS+CjpE/y1V1qIeR+IzhfQhTcqVBYcfH/Jg1HKIXlvNR6OdO6m8SawnPSzjgnxAFiXmp6m12M/xL6BYTYb8AaANnbZe6PgZCJzGqBwt6tGZ9hCcVLTavYXNO8fLcAqToZucCMMUs0mT+7NECsb0iSi1SD9FLaaEPNBIc3GvT4Lo1VcerRpy+6hJ1qzDWkZsQV7V4Kasfm/NIsH1Vu8/QkkQXi6J1CR5B2L9HjoXu2uA9qeEi8u7QUbB3T90+0PXwY/7J3VHZKwAkuxo3tfKyHcjJnJoBBsQ3RjGnVz3DOvvqNcs/xeZP5XQskdozP82vw== milenikaiqbal@gmail.com"
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJ7XAzKzFPAaScqA8tnLM99BzKkBv6U3pkdQWtVkZ/QZhasSbhWzieWHAvoKqQqR8aEGDO8BbXx6CAGnbJPXRfPtArgtyj3gm6UVQq4CBpJWI2hBdeMFHyzZmINs5SrgW20Lrh+XCJczLxXTvkv4tfok88IeEmnrSmrq0l6Y/1lVPK9Wrc9hjtycQGdooe3rKs8FicO3kinUa4C+t/vCoZbYbtSEI04rR/NvTwk3UFAhiOIVKDIqC7CuQaPz/s8bMQk8rOuVGkf8kM2rkUMYUN030AcgXzYuDoFLgUtonqqUGrF2liHj2owd83af2k+HRZL2fCqbNwY7Iz1vnUyxPpMWSjoQJixl6MMEBrJyn6TnYIHgeaa2YaIicOE9Ze1vpscfZ1oRrJfJU2sL+1elVEXkrqJfJlpRWHK0IfKTWtpdVD6j8x2RshAKMfBnavmhm2fIiizfePSE8VIlMWMQ9AzqQsyzXVsYXULRd+N4xfoWR6z4A8R4iTFIAqGneD08RX1JYQqaCicobxYYVIqCey3wbFY7AbahGsI7SdJsqkTUOdKIWYHiCsp1H2Hl0jMj5dERy/ZY2a8cFpZSjMG2cyJz0Ji8eMORg7fwrHMOmKDieSedAl4wk+cYHzRUR+9Mj9RubgFeO743i/7K8Yf+pKKzC3dhavtE8wY7qmh6Xa9Q== mikha@T440p"
      
      packages:
        - qemu-guest-agent
      
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve2"

  source_raw {
    file_name = "worker-hostname-init.yaml"
    data      = <<-EOT
      #cloud-config
      hostname: dev-k3s-worker-01
      manage_etc_hosts: true
      
      # Preserve existing SSH keys
      ssh_authorized_keys:
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSo7JnBBuSGhZp1EBI1D3zqAV5Y/zSr70LU21JYALlhv68W8wrMDQxn4KphXh2URGuYmCAF5/gyeV49Sinl0SbNErCqQGMPQlEYYm9eru+svEtaDhH5xuJYVzqoSTsS6iDsTp/kHASbnFb9lSAa0jo8RaXSbtzUHPL7lpO+YdVbKEJq0MK9B4dkNWsOHOnjFKJ35cL2u8h2SPHOZO7k7w3maPaDGrXaalv8skvfgPhrJ8zPwgs/r5g6X+LCl4LgVq4RZs9ssg+m389t4ezGoHyyfBqOzTgptugxb8Oq6Ml0nMe6f7sCudpYRc+/wwstCzarvowyPv5Cc9ZmnQOpuxAmU+GSR61T0+rZXtbcjwZVDS+CjpE/y1V1qIeR+IzhfQhTcqVBYcfH/Jg1HKIXlvNR6OdO6m8SawnPSzjgnxAFiXmp6m12M/xL6BYTYb8AaANnbZe6PgZCJzGqBwt6tGZ9hCcVLTavYXNO8fLcAqToZucCMMUs0mT+7NECsb0iSi1SD9FLaaEPNBIc3GvT4Lo1VcerRpy+6hJ1qzDWkZsQV7V4Kasfm/NIsH1Vu8/QkkQXi6J1CR5B2L9HjoXu2uA9qeEi8u7QUbB3T90+0PXwY/7J3VHZKwAkuxo3tfKyHcjJnJoBBsQ3RjGnVz3DOvvqNcs/xeZP5XQskdozP82vw== milenikaiqbal@gmail.com"
        - "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJ7XAzKzFPAaScqA8tnLM99BzKkBv6U3pkdQWtVkZ/QZhasSbhWzieWHAvoKqQqR8aEGDO8BbXx6CAGnbJPXRfPtArgtyj3gm6UVQq4CBpJWI2hBdeMFHyzZmINs5SrgW20Lrh+XCJczLxXTvkv4tfok88IeEmnrSmrq0l6Y/1lVPK9Wrc9hjtycQGdooe3rKs8FicO3kinUa4C+t/vCoZbYbtSEI04rR/NvTwk3UFAhiOIVKDIqC7CuQaPz/s8bMQk8rOuVGkf8kM2rkUMYUN030AcgXzYuDoFLgUtonqqUGrF2liHj2owd83af2k+HRZL2fCqbNwY7Iz1vnUyxPpMWSjoQJixl6MMEBrJyn6TnYIHgeaa2YaIicOE9Ze1vpscfZ1oRrJfJU2sL+1elVEXkrqJfJlpRWHK0IfKTWtpdVD6j8x2RshAKMfBnavmhm2fIiizfePSE8VIlMWMQ9AzqQsyzXVsYXULRd+N4xfoWR6z4A8R4iTFIAqGneD08RX1JYQqaCicobxYYVIqCey3wbFY7AbahGsI7SdJsqkTUOdKIWYHiCsp1H2Hl0jMj5dERy/ZY2a8cFpZSjMG2cyJz0Ji8eMORg7fwrHMOmKDieSedAl4wk+cYHzRUR+9Mj9RubgFeO743i/7K8Yf+pKKzC3dhavtE8wY7qmh6Xa9Q== mikha@T440p"
      
      packages:
        - qemu-guest-agent
      
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}

# --- Master VM (with unique hostname) ---
resource "proxmox_virtual_environment_vm" "master" {
  name      = "dev-k3s-master-01"
  node_name = "pve1"
  vm_id     = 801
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
        address = "192.168.1.81/24"
        gateway = "192.168.1.1"
      }
    }
  }
}

# --- Worker VM (with unique hostname) ---
resource "proxmox_virtual_environment_vm" "worker" {
  name      = "dev-k3s-worker-01"
  node_name = "pve2"
  vm_id     = 802
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
      name     = "dev-k3s-master-01"
      hostname = "dev-k3s-master-01"
      ip       = "192.168.1.81"
      node     = "pve1"
      vmid     = 801
    }
    workers = [
      {
        name     = "dev-k3s-worker-01"
        hostname = "dev-k3s-worker-01"
        ip       = "192.168.1.82"
        node     = "pve2"
        vmid     = 802
      }
    ]
    ssh_command = "ssh ubuntu@192.168.1.81  # Connect to master node"
  }
}
