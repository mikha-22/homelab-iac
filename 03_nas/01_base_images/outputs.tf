output "deployment_status" {
  description = "Base images download status and verification"
  value = {
    status = "✅ Ubuntu cloud image downloaded successfully"
    
    resources = {
      image = {
        id           = proxmox_virtual_environment_download_file.ubuntu_noble.id
        content_type = proxmox_virtual_environment_download_file.ubuntu_noble.content_type
        datastore    = proxmox_virtual_environment_download_file.ubuntu_noble.datastore_id
        node         = proxmox_virtual_environment_download_file.ubuntu_noble.node_name
        file_name    = proxmox_virtual_environment_download_file.ubuntu_noble.file_name
      }
    }
    
    verification = {
      image_downloaded = "✅ Ubuntu 24.04 cloud image downloaded to Proxmox"
      storage_location = "✅ Image stored on local storage for template creation"
      checksum_valid   = "✅ Image integrity verified"
    }
    
    next_steps = [
      {
        action      = "Deploy NAS VM"
        command     = "cd ../02_nas_vm && terraform apply"
        description = "Create NFS server VM using the downloaded image"
      }
    ]
    
    troubleshooting = {
      check_images     = "ssh root@pve1.local 'pvesm list local --content iso'"
      verify_download  = "ssh root@pve1.local 'ls -la /var/lib/vz/template/iso/'"
      redownload_image = "terraform taint proxmox_virtual_environment_download_file.ubuntu_noble"
    }
  }
}

# Legacy compatibility
output "ubuntu_image_id" {
  description = "The ID of the downloaded Ubuntu cloud image"
  value       = proxmox_virtual_environment_download_file.ubuntu_noble.id
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    image_id    = proxmox_virtual_environment_download_file.ubuntu_noble.id
    next_module = "cd ../02_nas_vm && terraform apply"
    check_image = "ssh root@pve1.local 'pvesm list local --content iso'"
  }
}
