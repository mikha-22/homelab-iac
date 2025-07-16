output "ubuntu_image" {
  description = "Downloaded Ubuntu image information"
  value = {
    id           = proxmox_virtual_environment_download_file.ubuntu_noble.id
    file_name    = proxmox_virtual_environment_download_file.ubuntu_noble.file_name
    datastore    = proxmox_virtual_environment_download_file.ubuntu_noble.datastore_id
    node         = proxmox_virtual_environment_download_file.ubuntu_noble.node_name
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_nas = "cd ../02_nas_vm && terraform apply"
    check_image = "ssh root@pve1.local 'pvesm list local --content iso'"
  }
}
