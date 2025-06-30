# ===================================================================
#  PHASE 2: PROVISION VMS ON SHARED STORAGE (FULLY AUTOMATED)
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

# ===================================================================
#  STAGE 1: PREPARE THE TEMPLATE
# ===================================================================

# --- Define the nodes where templates should be created ---
locals {
  nodes_for_templates = {
    "pve1" = { vmid = 9001 },
    "pve2" = { vmid = 9002 }
  }
}

# --- Create a minimal cloud-init for the templates ---
resource "proxmox_virtual_environment_file" "template_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "template-init.yaml"
    data      = <<-EOT
      #cloud-config
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}

# --- Create a TEMPLATE ON EACH NODE ---
resource "proxmox_virtual_environment_vm" "ubuntu_template" {
  for_each = local.nodes_for_templates

  name        = "ubuntu-2404-cloud-template-${each.key}"
  node_name   = each.key
  vm_id       = each.value.vmid
  template    = true

  depends_on = [proxmox_virtual_environment_file.template_cloud_init]

  agent { enabled = true }
  cpu { cores = 6 }
  memory { dedicated = 8192 }
  boot_order = ["scsi0"]

  disk {
    datastore_id = "cluster-shared-nfs"
    interface    = "scsi0"
    size         = 10
    file_id      = "cluster-shared-nfs:iso/noble-server-cloudimg-amd64.img"
  }

  initialization {
    datastore_id      = "cluster-shared-nfs"
    user_data_file_id = proxmox_virtual_environment_file.template_cloud_init.id
  }
}

# ===================================================================
#  STAGE 2: CLONE THE TEMPLATES TO CREATE WEB SERVERS
# ===================================================================

# --- Define the VMs we want to create ---
locals {
  vms_to_create = {
    "web-server-01" = { node = "pve1", vmid = 801, ip = "192.168.1.81/24" },
    "web-server-02" = { node = "pve2", vmid = 802, ip = "192.168.1.82/24" }
  }
}

# --- Create a unique cloud-init for EACH web server ---
# This resource now uses a for_each loop to generate a config for each VM.
resource "proxmox_virtual_environment_file" "webserver_cloud_init" {
  for_each = local.vms_to_create

  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1" # Snippets on shared storage are available to all nodes

  source_raw {
    file_name = "${each.key}-init.yaml" # e.g., "web-server-01-init.yaml"
    data      = <<-EOT
      #cloud-config
      # Set a unique hostname to prevent K3s registration conflicts
      hostname: ${each.key}
      fqdn: ${each.key}.local

      users:
        - name: mikha
          sudo: ALL=(ALL) NOPASSWD:ALL
          groups: users, admin
          shell: /bin/bash
          ssh_authorized_keys:
            - ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCSo7JnBBuSGhZp1EBI1D3zqAV5Y/zSr70LU21JYALlhv68W8wrMDQxn4KphXh2URGuYmCAF5/gyeV49Sinl0SbNErCqQGMPQlEYYm9eru+svEtaDhH5xuJYVzqoSTsS6iDsTp/kHASbnFb9lSAa0jo8RaXSbtzUHPL7lpO+YdVbKEJq0MK9B4dkNWsOHOnjFKJ35cL2u8h2SPHOZO7k7w3maPaDGrXaalv8skvfgPhrJ8zPwgs/r5g6X+LCl4LgVq4RZs9ssg+m389t4ezGoHyyfBqOzTgptugxb8Oq6Ml0nMe6f7sCudpYRc+/wwstCzarvowyPv5Cc9ZmnQOpuxAmU+GSR61T0+rZXtbcjwZVDS+CjpE/y1V1qIeR+IzhfQhTcqVBYcfH/Jg1HKIXlvNR6OdO6m8SawnPSzjgnxAFiXmp6m12M/xL6BYTYb8AaANnbZe6PgZCJzGqBwt6tGZ9hCcVLTavYXNO8fLcAqToZucCMMUs0mT+7NECsb0iSi1SD9FLaaEPNBIc3GvT4Lo1VcerRpy+6hJ1qzDWkZsQV7V4Kasfm/NIsH1Vu8/QkkQXi6J1CR5B2L9HjoXu2uA9qeEi8u7QUbB3T90+0PXwY/7J3VHZKwAkuxo3tfKyHcjJnJoBBsQ3RjGnVz3DOvvqNcs/xeZP5XQskdozP82vw== milenikaiqbal@gmail.com
      
      packages:
        - qemu-guest-agent

      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOT
  }
}

# --- Provision the VMs by cloning the correct node-local template ---
resource "proxmox_virtual_environment_vm" "web_servers" {
  for_each = local.vms_to_create

  name      = each.key
  node_name = each.value.node
  vm_id     = each.value.vmid
  tags      = ["web", "app"]

  clone {
    vm_id = proxmox_virtual_environment_vm.ubuntu_template[each.value.node].vm_id
  }

  cpu { cores = 6 }
  memory { dedicated = 8192 }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  disk {
    datastore_id = "cluster-shared-nfs"
    interface    = "scsi0"
    size         = 20
  }

  initialization {
    datastore_id      = "cluster-shared-nfs"
    # Point to the specific cloud-init file for this VM
    user_data_file_id = proxmox_virtual_environment_file.webserver_cloud_init[each.key].id
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
  description = "The IP addresses of the created web servers."
  value       = { for vm in proxmox_virtual_environment_vm.web_servers : vm.name => vm.initialization[0].ip_config[0].ipv4[0].address }
}
