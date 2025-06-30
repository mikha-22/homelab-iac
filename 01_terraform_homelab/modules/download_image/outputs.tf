output "file_id" {
  description = "The full ID of the downloaded file in Proxmox (e.g., 'local:iso/ubuntu-24.04-cloudimg.img')."
  value       = proxmox_virtual_environment_download_file.image.id
}
