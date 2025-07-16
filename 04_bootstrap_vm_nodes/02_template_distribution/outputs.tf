output "templates" {
  description = "Distributed template information"
  value = {
    source = {
      node        = "pve1"
      template_id = module.shared.vm_ids.base_template
      name        = var.source_template_name
    }
    distributed = [
      for target in var.target_nodes : {
        node        = target.node
        template_id = target.template_id
        name        = "${var.source_template_name}-${target.node}"
      }
    ]
  }
}

output "deployment_config" {
  description = "Template IDs for VM deployment"
  value = {
    master_template_id = 9000
    worker_template_id = 9010
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_vms      = "cd ../03_deploy_vm && terraform apply"
    check_templates = "ssh root@pve1.local 'qm list | grep template'"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    check_pve1_templates = "ssh root@pve1.local 'qm list | grep template'"
    check_pve2_templates = "ssh root@pve2.local 'qm list | grep template'"
    storage_content      = "ssh root@pve1.local 'ls -la /var/lib/vz/images/'"
    template_config      = "ssh root@pve1.local 'qm config ${module.shared.vm_ids.base_template}'"
  }
}
