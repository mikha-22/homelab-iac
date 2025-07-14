# ===================================================================
#  PROJECT: BASE IMAGES
#  Manages the downloading of OS images to Proxmox.
# ===================================================================

# --- GOOGLE PROVIDER FOR FETCHING SECRETS ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- DATA SOURCE TO FETCH PROXMOX API TOKEN ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

# --- PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  # CHANGED: Use the fetched secret directly
  api_token = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
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
