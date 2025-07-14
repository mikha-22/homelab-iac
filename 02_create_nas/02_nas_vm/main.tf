# ===================================================================
#  PROJECT: NAS VIRTUAL MACHINE
#  Provisions the NFS server VM, using a base image managed by the
#  '01-base-images' project.
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

# --- DATA SOURCE TO LINK PROJECTS ---
# This special block reads the state file from our 'base-images'
# project to get the output value for the image ID.
data "terraform_remote_state" "images" {
  backend = "local"

  config = {
    path = "../01_base_images/terraform.tfstate"
  }
}

# --- SECRET VARIABLES ---
variable "pm_api_token" {
  description = "The API token for the Proxmox provider."
  sensitive   = true
}
variable "pm_ssh_password" {
  description = "The root password for the Proxmox node, used by the SSH provisioner."
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

# --- CLOUD-INIT SCRIPT ---
resource "proxmox_virtual_environment_file" "nas_cloud_init" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = "pve1"

  source_raw {
    file_name = "nas-init.yaml"
    data      = <<-EOT
      #cloud-config
      users:
        - name: mikha
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, admin
          shell: /bin/bash
          ssh_authorized_keys:
            - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSo7JnBBuSGhZp1EBI1D3zqAV5Y/zSr70LU21JYALlhv68W8wrMDQxn4KphXh2URGuYmCAF5/gyeV49Sinl0SbNErCqQGMPQlEYYm9eru+svEtaDhH5xuJYVzqoSTsS6iDsTp/kHASbnFb9lSAa0jo8RaXSbtzUHPL7lpO+YdVbKEJq0MK9B4dkNWsOHOnjFKJ35cL2u8h2SPHOZO7k7w3maPaDGrXaalv8skvfgPhrJ8zPwgs/r5g6X+LCl4LgVq4RZs9ssg+m389t4ezGoHyyfBqOzTgptugxb8Oq6Ml0nMe6f7sCudpYRc+/wwstCzarvowyPv5Cc9ZmnQOpuxAmU+GSR61T0+rZXtbcjwZVDS+CjpE/y1V1qIeR+IzhfQhTcqVBYcfH/Jg1HKIXlvNR6OdO6m8SawnPSzjgnxAFiXmp6m12M/xL6BYTYb8AaANnbZe6PgZCJzGqBwt6tGZ9hCcVLTavYXNO8fLcAqToZucCMMUs0mT+7NECsb0iSi1SD9FLaaEPNBIc3GvT4Lo1VcerRpy+6hJ1qzDWkZsQV7V4Kasfm/NIsH1Vu8/QkkQXi6J1CR5B2L9HjoXu2uA9qeEi8u7QUbB3T90+0PXwY/7J3VHZKwAkuxo3tfKyHcjJnJoBBsQ3RjGnVz3DOvvqNcs/xeZP5XQskdozP82vw== milenikaiqbal@gmail.com
      
      ssh_pwauth: false
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
    # This is the magic link: it uses the output from the other project
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
  }

  # Give the VM time to boot, get an IP, and run the cloud-init script
  # to install and start the NFS server. This avoids the race condition.
  # You may need to adjust this value depending on your hardware speed.
  provisioner "local-exec" {
    command = "echo 'Waiting 20 seconds for VM to boot and NFS to start...' && sleep 20"
  }

  provisioner "local-exec" {
    command = <<-EOT
      for node in pve1.local pve2.local; do
        sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$node" "mkdir -p /mnt/pve/cluster-shared-nfs"
      done && \
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm add nfs cluster-shared-nfs --path /mnt/pve/cluster-shared-nfs --server 192.168.1.225 --export /export/proxmox-storage --content images,iso,vztmpl,snippets,backup,rootdir --nodes pve1,pve2"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "if pvesm status | grep -q '^cluster-shared-nfs '; then pvesm remove cluster-shared-nfs; fi" && \
      for node in pve1.local pve2.local; do
        sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$node" "umount -l /mnt/pve/cluster-shared-nfs || true; rmdir /mnt/pve/cluster-shared-nfs || true"
      done
    EOT
  }
}
