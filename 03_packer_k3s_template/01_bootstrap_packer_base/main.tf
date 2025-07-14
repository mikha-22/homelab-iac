# ===================================================================
#  PHASE 1: BOOTSTRAP PACKER BASE TEMPLATE - FIXED VERSION
#  Creates cloud-init file on SHARED storage for cross-node access
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
    data      = <<-EOT
      #cloud-config
      ssh_pwauth: false
      users:
        - name: ubuntu
          sudo: ALL=(ALL) NOPASSWD:ALL
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
