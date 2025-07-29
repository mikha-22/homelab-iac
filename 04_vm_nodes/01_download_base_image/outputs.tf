output "base_template" {
  description = "Base template information"
  value = {
    name        = proxmox_virtual_environment_vm.base_cloud_template.name
    template_id = proxmox_virtual_environment_vm.base_cloud_template.vm_id
    node        = proxmox_virtual_environment_vm.base_cloud_template.node_name
    storage     = "cluster-shared-nfs"
  }
}

output "cloud_init" {
  description = "Cloud-init configuration"
  value = {
    file_name = "base-template-init.yaml"
    datastore = "cluster-shared-nfs"
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    distribute_templates = "cd ../02_template_distribution && terraform apply"
    check_template       = "ssh root@pve1.local 'qm list | grep ${proxmox_virtual_environment_vm.base_cloud_template.vm_id}'"
  }
}
