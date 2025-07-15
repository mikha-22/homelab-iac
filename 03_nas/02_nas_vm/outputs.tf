output "nas_vm_name" {
  description = "The name of the NFS server VM."
  value       = proxmox_virtual_environment_vm.nfs_server.name
}

output "nas_vm_ip_address" {
  description = "The IP address of the NFS server VM."
  value       = proxmox_virtual_environment_vm.nfs_server.initialization[0].ip_config[0].ipv4[0].address
}

output "nfs_storage_path" {
  description = "The NFS export path for use in other services."
  value       = "192.168.1.225:/export/proxmox-storage"
}
