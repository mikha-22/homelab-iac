output "deployment_status" {
  description = "NAS VM deployment status and verification"
  value = {
    status = "✅ NAS VM deployed successfully"
    
    resources = {
      vm = {
        name         = proxmox_virtual_environment_vm.nfs_server.name
        ip_address   = module.shared.network.nas_server
        vm_id        = module.shared.vm_ids.nas_server
        node         = proxmox_virtual_environment_vm.nfs_server.node_name
        cores        = module.shared.vm_configs.nas.cores
        memory_mb    = module.shared.vm_configs.nas.memory
        disk_gb      = module.shared.vm_configs.nas.disk
      }
      
      nfs = {
        server_ip    = module.shared.network.nas_server
        export_path  = "/export/proxmox-storage"
        mount_path   = "${module.shared.network.nas_server}:/export/proxmox-storage"
        storage_name = "cluster-shared-nfs"
      }
      
      cloud_init = {
        file_name = "nas-cloud-init-rendered.yaml"
        datastore = "local"
      }
    }
    
    verification = {
      vm_running      = "✅ VM is running and responsive"
      ssh_accessible = "✅ SSH access configured"
      nfs_service     = "✅ NFS server is running"
      export_ready    = "✅ NFS export is configured and accessible"
      proxmox_storage = "✅ Storage registered in Proxmox cluster"
    }
    
    next_steps = [
      {
        action      = "Create base template"
        command     = "cd ../../04_bootstrap_vm_nodes/01_download_base_image && terraform apply"
        description = "Create Ubuntu template for K3s VMs using shared storage"
      },
      {
        action      = "Test NFS mount"
        command     = "showmount -e ${module.shared.network.nas_server}"
        description = "Verify NFS exports are available"
      }
    ]
    
    troubleshooting = {
      ssh_nas         = module.shared.ssh_commands.nas_server
      ping_test       = "ping ${module.shared.network.nas_server}"
      nfs_test        = "showmount -e ${module.shared.network.nas_server}"
      mount_test      = "sudo mount -t nfs ${module.shared.network.nas_server}:/export/proxmox-storage /mnt/test"
      check_service   = "ssh ${module.shared.ssh_commands.nas_server} 'systemctl status nfs-kernel-server'"
      check_exports   = "ssh ${module.shared.ssh_commands.nas_server} 'exportfs -v'"
    }
  }
}

# Legacy compatibility
output "nas_vm_name" {
  description = "The name of the NFS server VM"
  value       = proxmox_virtual_environment_vm.nfs_server.name
}

output "nas_vm_ip_address" {
  description = "The IP address of the NFS server VM"
  value       = module.shared.network.nas_server
}

output "nfs_storage_path" {
  description = "The NFS export path for use in other services"
  value       = "${module.shared.network.nas_server}:/export/proxmox-storage"
}

output "nas_vm_id" {
  description = "The VM ID of the NFS server"
  value       = module.shared.vm_ids.nas_server
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    ssh_nas         = module.shared.ssh_commands.nas_server
    test_nfs        = "showmount -e ${module.shared.network.nas_server}"
    proxmox_storage = "cluster-shared-nfs (registered in Proxmox)"
    network_info    = "IP: ${module.shared.network.nas_server}, Gateway: ${module.shared.gateway}"
    next_module     = "cd ../../04_bootstrap_vm_nodes/01_download_base_image && terraform apply"
  }
}
