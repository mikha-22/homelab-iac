output "ubuntu_image_id" {
  description = "The ID of the downloaded Ubuntu cloud image."
  value       = proxmox_virtual_environment_download_file.ubuntu_noble.id
}
