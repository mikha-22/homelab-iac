# ===================================================================
#  PROJECT: BASE IMAGES
#  Manages the downloading of OS images to Proxmox.
# ===================================================================

# --- DATA SOURCE TO FETCH PROXMOX API TOKEN ---
# This data source is needed by the proxmox provider configuration.
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

# --- IMAGE DOWNLOAD RESOURCE ---
resource "proxmox_virtual_environment_download_file" "ubuntu_noble" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve1"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite    = false
}
