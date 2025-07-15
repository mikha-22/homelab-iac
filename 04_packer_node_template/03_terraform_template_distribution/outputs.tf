output "distributed_templates" {
  description = "Information about distributed templates"
  value = {
    source = {
      node        = "pve1"
      template_id = var.source_template_id
      name        = var.source_template_name
      status      = "Source template (moved to shared storage)"
    }
    targets = [
      for i, target in var.target_nodes : {
        node        = target.node
        template_id = target.template_id
        name        = "${var.source_template_name}-${target.node}"
        status      = "Distributed template (on shared storage)"
      }
    ]
  }
  depends_on = [null_resource.distribute_template]
}

output "terraform_vm_config" {
  description = "Terraform configuration snippet for VM deployment"
  value = <<-EOT
    # Use this in your VM deployment Terraform:
    locals {
      vms_to_create = {
        "dev-k3s-master-01" = { node = "pve1", vmid = 801, ip = "192.168.1.81/24", template_id = ${var.source_template_id} },
        ${join(",\n        ", [
          for target in var.target_nodes :
          "\"dev-k3s-worker-${substr(target.node, -1, 1)}\" = { node = \"${target.node}\", vmid = ${target.template_id + 1}, ip = \"192.168.1.${80 + target.template_id + 1}/24\", template_id = ${target.template_id} }"
        ])}
      }
    }
  EOT
  depends_on = [null_resource.distribute_template]
}
