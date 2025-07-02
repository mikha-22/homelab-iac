# ===================================================================
#  PROJECT: BASE IMAGES OUTPUTS
#  Exposes the IDs of managed resources so other projects can
#  read them from this project's state file.
# ===================================================================

output "ubuntu_image_id" {
  description = "The Proxmox ID for the downloaded Ubuntu Noble cloud image (e.g. 'local:iso/ubuntu-24.04-cloudimg.img')."
  value       = proxmox_virtual_environment_download_file.ubuntu_noble.id
}
