output "deployment_status" {
  description = "Base template deployment status and verification"
  value = {
    status = "✅ Base template created successfully"
    
    resources = {
      template = {
        name        = proxmox_virtual_environment_vm.base_cloud_template.name
        template_id = proxmox_virtual_environment_vm.base_cloud_template.vm_id
        node        = proxmox_virtual_environment_vm.base_cloud_template.node_name
        storage     = "cluster-shared-nfs"
        description = "Base cloud-image template for VM deployment - no Packer needed!"
      }
      
      cloud_init = {
        file_name = "base-template-init.yaml"
        datastore = "cluster-shared-nfs"
        ssh_key   = "✅ SSH key configured from Secret Manager"
      }
      
      base_image = {
        source_id = data.terraform_remote_state.base_images.outputs.ubuntu_image_id
        os_type   = "Ubuntu 24.04 LTS"
      }
    }
    
    verification = {
      template_created = "✅ Template VM created and marked as template"
      shared_storage   = "✅ Template stored on shared storage"
      cloud_init_ready = "✅ Cloud-init configuration uploaded"
      ssh_configured   = "✅ SSH access configured with secret manager key"
    }
    
    next_steps = [
      {
        action      = "Distribute templates"
        command     = "cd ../02_template_distribution && terraform apply"
        description = "Clone base template to all Proxmox nodes for VM deployment"
      }
    ]
    
    troubleshooting = {
      check_template   = "ssh root@pve1.local 'qm list | grep ${proxmox_virtual_environment_vm.base_cloud_template.vm_id}'"
      verify_storage   = "ssh root@pve1.local 'pvesm status -storage cluster-shared-nfs'"
      template_config  = "ssh root@pve1.local 'qm config ${proxmox_virtual_environment_vm.base_cloud_template.vm_id}'"
      check_cloud_init = "ssh root@pve1.local 'ls -la /var/lib/vz/snippets/ | grep base-template'"
    }
  }
}

# Legacy compatibility
output "base_template_name" {
  description = "The name of the base template created"
  value       = proxmox_virtual_environment_vm.base_cloud_template.name
}

output "base_template_id" {
  description = "The VM ID of the base template"
  value       = proxmox_virtual_environment_vm.base_cloud_template.vm_id
}

output "base_template_node" {
  description = "The Proxmox node where the base template was created"
  value       = proxmox_virtual_environment_vm.base_cloud_template.node_name
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    template_id   = proxmox_virtual_environment_vm.base_cloud_template.vm_id
    template_name = proxmox_virtual_environment_vm.base_cloud_template.name
    next_module   = "cd ../02_template_distribution && terraform apply"
    check_template = "ssh root@pve1.local 'qm list | grep ${proxmox_virtual_environment_vm.base_cloud_template.vm_id}'"
  }
}
