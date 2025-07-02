packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# --- Variables ---
# These are loaded automatically from .pkrvars.hcl and .auto.pkrvars.hcl files
variable "pm_api_token" {
  type      = string
  sensitive = true
  description = "Proxmox API Token in the format 'user@realm!tokenid=secret'."
}

variable "ssh_private_key_file" {
  type = string
  description = "Path to the SSH private key for connecting to the VM."
}

variable "proxmox_url" {
  type    = string
  default = "https://pve1.local:8006/api2/json"
}

variable "base_template_name" {
  type    = string
  default = "ubuntu-2404-cloud-base"
}

variable "base_template_node" {
  type    = string
  default = "pve1"
}

variable "new_template_id" {
  type    = number
  default = 9000
}

variable "new_template_name" {
  type    = string
  default = "ubuntu-2404-k3s-template"
}

variable "storage_pool" {
  type    = string
  default = "cluster-shared-nfs"
  description = "Storage pool for cloud-init storage"
}

# --- Locals ---
# Parse the Proxmox API token into its user/tokenid and secret parts
locals {
  proxmox_auth = split("=", var.pm_api_token)
}

# --- Builder ---
# Clones the base VM, provisions it, and creates a new template
source "proxmox-clone" "k3s_template" {
  # --- Proxmox Connection ---
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = true
  username                 = local.proxmox_auth[0]
  token                    = local.proxmox_auth[1]

  # --- Source VM ---
  node     = var.base_template_node
  clone_vm = var.base_template_name

  # --- CRITICAL FIX: Use full clone for local-lvm storage ---
  full_clone = true

  # --- Communicator ---
  communicator           = "ssh"
  ssh_username           = "ubuntu"
  ssh_private_key_file   = var.ssh_private_key_file
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 20

  # --- New Template ---
  vm_id                = var.new_template_id
  template_name        = var.new_template_name
  template_description = "Golden Image: Ubuntu 24.04 with k3s pre-installed."
  
  # --- Hardware Configuration ---
  cores  = 2
  memory = 4096
  
  # --- CRITICAL: Match the template's SCSI controller ---
  scsi_controller = "virtio-scsi-pci"
  
  # --- Network Configuration ---
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
  
  # --- Cloud-init Configuration ---
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool  # Use shared NFS storage for cloud-init
  
  # --- DNS Configuration ---
  nameserver = "1.1.1.1 8.8.8.8"
  
  # --- Boot Configuration ---
  boot_wait = "30s"
}

# --- Build ---
# Defines the steps to provision the VM
build {
  sources = ["source.proxmox-clone.k3s_template"]

  # Step 1: Wait for cloud-init and update the OS
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to finish...'",
      "sudo cloud-init status --wait",
      "echo 'Cloud-init finished. Updating packages...'",
      "sudo apt-get update",
      "sudo DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade",
      "echo 'Package update complete.'"
    ]
  }

  # Step 2: Install k3s
  provisioner "shell" {
    inline = [
      "echo 'Installing k3s...'",
      "curl -sfL https://get.k3s.io | sh -s -",
      "echo 'k3s installation complete.'"
    ]
  }
  
  # Step 3: Clean up the image to make it a generic template
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up image for templating...'",
      "sudo systemctl stop k3s",
      "sudo systemctl disable k3s",
      "sudo rm -f /var/lib/rancher/k3s/server/token",
      "sudo rm -rf /var/lib/rancher/k3s/server/db/etcd/member/wal/* || true",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo cloud-init clean -s -l",
      "history -c || true",
      "cat /dev/null > ~/.bash_history"
    ]
    expect_disconnect = true
  }
}
