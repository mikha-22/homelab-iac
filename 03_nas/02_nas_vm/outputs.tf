output "nas_vm" {
  description = "NAS VM information"
  value = {
    name         = proxmox_virtual_environment_vm.nfs_server.name
    ip_address   = module.shared.network.nas_server
    vm_id        = module.shared.vm_ids.nas_server
    node         = proxmox_virtual_environment_vm.nfs_server.node_name
    ssh_command  = module.shared.ssh_commands.nas_server
  }
}

output "nfs_config" {
  description = "NFS configuration"
  value = {
    server_ip    = module.shared.network.nas_server
    export_path  = "/export/proxmox-storage"
    mount_path   = "${module.shared.network.nas_server}:/export/proxmox-storage"
    storage_name = "cluster-shared-nfs"
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    create_template = "cd ../../04_bootstrap_vm_nodes/01_download_base_image && terraform apply"
    test_nfs        = "showmount -e ${module.shared.network.nas_server}"
    test_mount      = "sudo mount -t nfs ${module.shared.network.nas_server}:/export/proxmox-storage /mnt/test"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    ping_nas       = "ping ${module.shared.network.nas_server}"
    ssh_nas        = module.shared.ssh_commands.nas_server
    check_nfs      = "ssh ${module.shared.ssh_commands.nas_server} 'systemctl status nfs-kernel-server'"
    check_exports  = "ssh ${module.shared.ssh_commands.nas_server} 'exportfs -v'"
  }
}
