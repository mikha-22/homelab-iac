# ===================================================================
#  PROJECT: NAS VIRTUAL MACHINE
#  Provisions the NFS server VM and configures Proxmox storage.
# ===================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

# --- SECRET VARIABLES ---
# These variables are expected to be passed in via environment variables
# (e.g., from your set_env.fish script)
variable "pm_api_token" {
  description = "The API token for the Proxmox provider."
  sensitive   = true
}

variable "pm_ssh_password" {
  description = "The SSH password for the Proxmox nodes."
  sensitive   = true
}

# --- PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = var.pm_api_token
}

# --- DATA SOURCES ---
# This data block reads the output from the '01_base_images' project.
# It's how we find the ID of the Ubuntu cloud image we downloaded.
data "terraform_remote_state" "base_images" {
  backend = "local"
  config = {
    path = "../01_base_images/terraform.tfstate"
  }
}

# --- VIRTUAL MACHINE RESOURCE (THIS IS THE MISSING PIECE) ---
# This block defines and creates the NFS server virtual machine.
resource "proxmox_virtual_environment_vm" "nfs_server" {
  name        = "nfs-server"
  description = "Managed by Terraform"
  tags        = ["terraform", "nfs"]
  node_name   = "pve1" # The node to create the VM on

  # --- VM Template and OS ---
  os_type = "cloud-init"
  agent {
    enabled = true # Enable the QEMU guest agent
    fs_trim = true
  }

  # --- Hardware ---
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 2048 # 2GB RAM
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio-net"
  }

  disk {
    interface    = "scsi0"
    datastore_id = "local-lvm" # Storage for the VM's root disk
    size         = 32          # Root disk size in GB
  }

  # --- CLOUD-INIT CONFIGURATION ---
  # This section configures the VM on its first boot.
  initialization {
    # This points to the cloud image we downloaded in the other project.
    image_id = data.terraform_remote_state.base_images.outputs.ubuntu_image_id

    # Sets the static IP address for the VM.
    ip_config {
      ipv4 {
        address = "192.168.1.70/24"
        gateway = "192.168.1.1"
      }
    }

    # Sets up the default user and injects your SSH public key.
    # !!! IMPORTANT: REPLACE THE KEY BELOW WITH YOUR OWN PUBLIC SSH KEY !!!
    user_account {
      username = "ubuntu"
      keys     = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB... your-user@your-machine"]
    }
  }

  # --- AUTOMATION ---
  lifecycle {
    ignore_changes = [
      network_device, # Allows Proxmox to assign a MAC address without Terraform seeing a change.
    ]
  }
}


# ===================================================================
#  YOUR ORIGINAL CODE STARTS HERE
#  These resources now correctly depend on the VM defined above.
# ===================================================================

# --- CREATE MOUNT DIRECTORIES ON PROXMOX NODES ---
resource "null_resource" "create_mount_directories" {
  # This now correctly refers to the VM resource defined above.
  depends_on = [proxmox_virtual_environment_vm.nfs_server]

  triggers = {
    # This trigger ensures the resource re-runs if the VM is recreated.
    vm_id = proxmox_virtual_environment_vm.nfs_server.id
  }

  # Give the VM time to boot and start NFS service
  provisioner "local-exec" {
    command = "echo 'Waiting 60 seconds for VM to boot and NFS to start...' && sleep 60"
  }

  # Create mount directories on both Proxmox nodes
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "mkdir -p /mnt/pve/cluster-shared-nfs"
    EOT
  }

  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve2.local "mkdir -p /mnt/pve/cluster-shared-nfs"
    EOT
  }

  # Test NFS connectivity before proceeding
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "showmount -e 192.168.1.70"
    EOT
  }

  # Test manual mount to verify NFS is working
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "mount -t nfs 192.168.1.70:/export/proxmox-storage /mnt/pve/cluster-shared-nfs && ls /mnt/pve/cluster-shared-nfs && umount /mnt/pve/cluster-shared-nfs"
    EOT
  }
}

# --- REGISTER THE NFS STORAGE IN PROXMOX (UPDATED) ---
resource "null_resource" "register_nfs_storage" {
  depends_on = [null_resource.create_mount_directories]  # Wait for directories to be created

  triggers = {
    vm_id = proxmox_virtual_environment_vm.nfs_server.id
  }

  # Remove any existing broken storage first
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm remove cluster-shared-nfs" || echo "No existing storage to remove"
    EOT
  }

  # Register the NFS storage
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm add nfs cluster-shared-nfs --path /mnt/pve/cluster-shared-nfs --server 192.168.1.70 --export /export/proxmox-storage --content images,iso,vztmpl,snippets,backup,rootdir --nodes pve1,pve2"
    EOT
  }

  # Verify the storage is working
  provisioner "local-exec" {
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm status | grep cluster-shared-nfs"
    EOT
  }

  # This provisioner runs when you 'terraform destroy'
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      sshpass -p "$TF_VAR_pm_ssh_password" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@pve1.local "pvesm remove cluster-shared-nfs"
    EOT
  }
}
