output "base_template_name" {
  description = "The name of the base template created for Packer."
  value       = proxmox_virtual_environment_vm.base_cloud_template.name
}

output "base_template_id" {
  description = "The VM ID of the base template."
  value       = proxmox_virtual_environment_vm.base_cloud_template.vm_id
}

output "base_template_node" {
  description = "The Proxmox node where the base template was created."
  value       = proxmox_virtual_environment_vm.base_cloud_template.node_name
}
