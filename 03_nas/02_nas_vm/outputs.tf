# ===================================================================
#  SIMPLIFIED OUTPUTS - ESSENTIAL DATA ONLY
#  Example for any module (e.g., 03_nas/02_nas_vm/outputs.tf)
# ===================================================================

output "nas_vm" {
  description = "NAS VM information"
  value = {
    name       = proxmox_virtual_environment_vm.nfs_server.name
    ip_address = module.shared.network.nas_server
    vm_id      = module.shared.vm_ids.nas_server
    ssh        = module.shared.ssh_commands.nas_server
  }
}

output "nfs_config" {
  description = "NFS configuration"
  value = {
    server_ip    = module.shared.network.nas_server
    export_path  = "/export/proxmox-storage"
    storage_name = "cluster-shared-nfs"
  }
}
