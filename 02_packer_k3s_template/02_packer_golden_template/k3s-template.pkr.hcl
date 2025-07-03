packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# --- Variables ---
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
  default = "ubuntu-2404-clean-template"
}

variable "storage_pool" {
  type    = string
  default = "cluster-shared-nfs"
  description = "Storage pool for cloud-init storage"
}

# --- Locals ---
locals {
  proxmox_auth = split("=", var.pm_api_token)
}

# --- Builder ---
source "proxmox-clone" "clean_template" {
  # --- Proxmox Connection ---
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = true
  username                 = local.proxmox_auth[0]
  token                    = local.proxmox_auth[1]

  # --- Source VM ---
  node     = var.base_template_node
  clone_vm = var.base_template_name

  # --- Use full clone for local-lvm storage ---
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
  template_description = "Clean Ubuntu 24.04 template for K3s deployment via Ansible."
  
  # --- Hardware Configuration ---
  cores  = 2
  memory = 4096
  
  # --- Match the template's SCSI controller ---
  scsi_controller = "virtio-scsi-pci"
  
  # --- Network Configuration ---
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    firewall = false
  }
  
  # --- Cloud-init Configuration ---
  cloud_init              = true
  cloud_init_storage_pool = var.storage_pool
  
  # --- DNS Configuration ---
  nameserver = "1.1.1.1 8.8.8.8"
  
  # --- Boot Configuration ---
  boot_wait = "30s"
}

# --- Build ---
build {
  sources = ["source.proxmox-clone.clean_template"]

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

  # Step 2: Install common packages that K3s will need
  provisioner "shell" {
    inline = [
      "echo 'Installing common packages for K3s...'",
      "sudo apt-get install -y curl wget apt-transport-https ca-certificates software-properties-common",
      "echo 'Common packages installed.'"
    ]
  }
  
  # Step 3: Clean up the image to make it a generic template
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up image for templating...'",
      # Clean SSH host keys so each VM gets unique ones
      "sudo rm -f /etc/ssh/ssh_host_*",
      # Clean cloud-init state
      "sudo cloud-init clean -s -l",
      # Clean bash history
      "history -c || true",
      "cat /dev/null > ~/.bash_history",
      # Clean package cache
      "sudo apt-get clean",
      # Clean logs
      "sudo truncate -s 0 /var/log/*log",
      "echo 'Image cleanup complete - ready for K3s deployment via Ansible.'",
      "sudo systemctl enable ssh"
    ]
    expect_disconnect = true
  }
}
