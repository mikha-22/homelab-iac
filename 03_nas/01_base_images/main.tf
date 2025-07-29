# ===================================================================
#  PROJECT: BASE IMAGES - UPDATED
#  Manages the downloading of OS images to Proxmox.
#  Shared module is now loaded in providers.tf, not here
# ===================================================================

# --- IMAGE DOWNLOAD RESOURCE ---
resource "proxmox_virtual_environment_download_file" "ubuntu_noble" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "pve1"
  url          = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
  overwrite    = false
}
