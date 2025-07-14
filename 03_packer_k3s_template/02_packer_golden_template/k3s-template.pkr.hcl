/*
=================================================================
  FIXED PACKER TEMPLATE - JUST RUN: packer build .
=================================================================
Set environment variable first:
export PKR_VAR_pm_api_token=$(gcloud secrets versions access latest --secret=proxmox-api-token)

Then run:
packer build .
=================================================================
*/

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
  description = "Proxmox API Token - set via PKR_VAR_pm_api_token environment variable"
}

variable "ssh_private_key_file" {
  type = string
  description = "Path to the SSH private key for connecting to the VM."
  default = "~/.ssh/id_rsa"
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

  # --- Use full clone ---
  full_clone = true

  # --- Communicator ---
  communicator           = "ssh"
  ssh_username           = "ubuntu"
  ssh_private_key_file   = var.ssh_private_key_file
  ssh_timeout            = "20m"
  ssh_handshake_attempts = 200
  ssh_pty                = true

  # --- New Template ---
  vm_id                = var.new_template_id
  template_name        = var.new_template_name
  template_description = "K3s-ready Ubuntu 24.04 template"
  
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
  
  # --- CRITICAL: Longer boot wait ---
  boot_wait = "120s"
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
    timeout = "30m"
  }

  # Step 2: Install packages for K3s
  provisioner "shell" {
    inline = [
      "echo 'Installing K3s prerequisites...'",
      "sudo apt-get install -y curl wget apt-transport-https ca-certificates software-properties-common nfs-common open-iscsi",
      "echo 'Prerequisites installed.'"
    ]
  }

  # Step 3: Configure system for K3s
  provisioner "shell" {
    inline = [
      "echo 'Configuring system for K3s...'",
      "sudo modprobe br_netfilter",
      "sudo modprobe overlay",
      "echo 'br_netfilter' | sudo tee /etc/modules-load.d/k3s.conf",
      "echo 'overlay' | sudo tee -a /etc/modules-load.d/k3s.conf",
      "echo 'net.bridge.bridge-nf-call-iptables = 1' | sudo tee /etc/sysctl.d/k3s.conf",
      "echo 'net.bridge.bridge-nf-call-ip6tables = 1' | sudo tee -a /etc/sysctl.d/k3s.conf",
      "echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/k3s.conf",
      "sudo sysctl --system",
      "echo 'System configuration complete.'"
    ]
  }
  
  # Step 4: Clean up for templating
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up for template creation...'",
      "sudo rm -f /etc/ssh/ssh_host_*",
      "sudo cloud-init clean -s -l",
      "history -c || true",
      "cat /dev/null > ~/.bash_history",
      "sudo apt-get clean",
      "sudo apt-get autoremove -y",
      "sudo truncate -s 0 /var/log/*log",
      "sudo find /var/log -type f -name '*.log' -exec truncate -s 0 {} \\;",
      "echo 'Template cleanup complete.'",
      "sudo systemctl enable ssh",
      "sudo sync"
    ]
    expect_disconnect = true
  }
}
