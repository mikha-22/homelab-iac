# ===================================================================
#  PHASE 1: PROVISION THE NAS VIRTUAL MACHINE
# ===================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
  }
}

# --- SECRET VARIABLES ---
variable "pm_api_token" {
  description = "The API token for the Proxmox provider."
  sensitive   = true
}
variable "pm_ssh_password" {
  description = "The password for the Proxmox node's root user (for SSH operations)."
  sensitive   = true
}

# --- PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = var.pm_api_token
  ssh {
    username = "root"
    password = var.pm_ssh_password
  }
}

# --- DOWNLOAD THE BASE OS IMAGE ---
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image_pve1" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve1"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  file_name    = "ubuntu-24.04-cloudimg.img"
  overwrite    = false
}

# --- DEFINE THE CLOUD-INIT SCRIPT FOR THE NAS ---
resource "proxmox_virtual_environment_file" "nas_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    file_name = "nas-init.yaml"
    data      = <<-EOT
      #cloud-config
      # ==> Add a new user and set their password <==
      users:
        - name: mikha
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, admin
          shell: /bin/bash
          password: ikantuna
          ssh_authorized_keys:
            - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSo7JnBBuSGhZp1EBI1D3zqAV5Y/zSr70LU21JYALlhv68W8wrMDQxn4KphXh2URGuYmCAF5/gyeV49Sinl0SbNErCqQGMPQlEYYm9eru+svEtaDhH5xuJYVzqoSTsS6iDsTp/kHASbnFb9lSAa0jo8RaXSbtzUHPL7lpO+YdVbKEJq0MK9B4dkNWsOHOnjFKJ35cL2u8h2SPHOZO7k7w3maPaDGrXaalv8skvfgPhrJ8zPwgs/r5g6X+LCl4LgVq4RZs9ssg+m389t4ezGoHyyfBqOzTgptugxb8Oq6Ml0nMe6f7sCudpYRc+/wwstCzarvowyPv5Cc9ZmnQOpuxAmU+GSR61T0+rZXtbcjwZVDS+CjpE/y1V1qIeR+IzhfQhTcqVBYcfH/Jg1HKIXlvNR6OdO6m8SawnPSzjgnxAFiXmp6m12M/xL6BYTYb8AaANnbZe6PgZCJzGqBwt6tGZ9hCcVLTavYXNO8fLcAqToZucCMMUs0mT+7NECsb0iSi1SD9FLaaEPNBIc3GvT4Lo1VcerRpy+6hJ1qzDWkZsQV7V4Kasfm/NIsH1Vu8/QkkQXi6J1CR5B2L9HjoXu2uA9qeEi8u7QUbB3T90+0PXwY/7J3VHZKwAkuxo3tfKyHcjJnJoBBsQ3RjGnVz3DOvvqNcs/xeZP5XQskdozP82vw== milenikaiqbal@gmail.com


      # ==> Enable SSH password authentication <==
      ssh_pwauth: true

      packages:
        - nfs-kernel-server
        - qemu-guest-agent

      runcmd:
        - systemctl enable --now qemu-guest-agent
        - mkdir -p /export/proxmox-storage
        - chown nobody:nogroup /export/proxmox-storage
        - chmod 777 /export/proxmox-storage
        - 'echo "/export/proxmox-storage *(rw,sync,no_subtree_check,no_root_squash)" > /etc/exports'
        - exportfs -a
        - systemctl restart nfs-kernel-server
    EOT
  }
}

# --- PROVISION THE NAS VIRTUAL MACHINE ---
resource "proxmox_virtual_environment_vm" "nfs_server" {
  name        = "nfs-server-01"
  description = "NFS server for Proxmox cluster shared storage"
  tags        = ["nas", "nfs", "infra"]
  node_name   = "pve1"
  vm_id       = 700

  depends_on = [
    proxmox_virtual_environment_download_file.ubuntu_cloud_image_pve1,
    proxmox_virtual_environment_file.nas_cloud_init
  ]

  # Hardware configuration with corrected HCL syntax
  cpu {
    cores = 1
  }
  memory {
    dedicated = 2048
  }
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
    file_id      = proxmox_virtual_environment_download_file.ubuntu_cloud_image_pve1.id
    discard      = "on"
  }

  on_boot = true

  initialization {
    datastore_id = "local-lvm"
    
    ip_config {
      ipv4 {
        address = "192.168.1.70/24"
        gateway = "192.168.1.1"
      }
    }
    dns {
      servers = ["1.1.1.1", "8.8.8.8"]
    }
    
    user_data_file_id = proxmox_virtual_environment_file.nas_cloud_init.id
  }
}
