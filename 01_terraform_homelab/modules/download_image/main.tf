# This resource downloads the specified file to the target node's datastore.
resource "proxmox_virtual_environment_download_file" "image" {
  content_type = var.content_type
  datastore_id = var.datastore_id
  node_name    = var.node_name
  url          = var.url

  # If a file_name is provided, use it. Otherwise, extract it from the URL.
  file_name    = var.file_name != "" ? var.file_name : basename(var.url)

  # We set overwrite to false to prevent re-downloads on subsequent applies.
  overwrite    = false
}
