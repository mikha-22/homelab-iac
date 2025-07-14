# ===================================================================
#  PROJECT: BASE IMAGES
#  Manages the downloading of OS images to Proxmox.
#  This configuration should be run once and rarely changed.
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

# --- PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = var.pm_api_token
}

# --- IMAGE DOWNLOAD RESOURCE ---
resource "proxmox_virtual_environment_download_file" "ubuntu_noble" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve1"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite    = false
}
      
output "ubuntu_image_id" {
  description = "The ID of the downloaded Ubuntu cloud image."
  value       = proxmox_virtual_environment_download_file.ubuntu_noble.id
}


