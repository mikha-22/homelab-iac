output "templates" {
  description = "Distributed template information"
  value = {
    master_template_id = 9000
    worker_template_id = 9010
    base_template_id   = module.shared.vm_ids.base_template
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_vms = "cd ../03_deploy_vm && terraform apply"
  }
}
