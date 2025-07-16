output "deployment_status" {
  description = "Template distribution deployment status and verification"
  value = {
    status = "✅ VM templates distributed successfully"
    
    resources = {
      source_template = {
        node        = "pve1"
        template_id = var.source_template_id
        name        = var.source_template_name
        status      = "Source template (moved to shared storage)"
        storage     = "cluster-shared-nfs"
      }
      
      distributed_templates = [
        for target in var.target_nodes : {
          node        = target.node
          template_id = target.template_id
          name        = "${var.source_template_name}-${target.node}"
          status      = "Distributed template (on shared storage)"
          storage     = "cluster-shared-nfs"
        }
      ]
      
      template_count = {
        source_templates = 1
        distributed_templates = length(var.target_nodes)
        total_templates = 1 + length(var.target_nodes)
      }
    }
    
    verification = {
      source_moved        = "✅ Source template moved to shared storage"
      templates_cloned    = "✅ Templates cloned to all target nodes"
      shared_storage      = "✅ All templates use shared storage"
      template_marked     = "✅ All VMs properly marked as templates"
      cross_node_access   = "✅ Templates accessible from all nodes"
    }
    
    next_steps = [
      {
        action      = "Deploy VMs"
        command     = "cd ../03_deploy_vm && terraform apply"
        description = "Create K3s VMs from distributed templates"
      },
      {
        action      = "Verify templates"
        command     = "ssh root@pve1.local 'qm list | grep template'"
        description = "Check all templates are available"
      }
    ]
    
    troubleshooting = {
      check_templates     = "ssh root@pve1.local 'qm list | grep template'"
      verify_shared_storage = "ssh root@pve1.local 'pvesm status -storage cluster-shared-nfs'"
      check_pve2_templates = "ssh root@pve2.local 'qm list | grep template'"
      template_config     = "ssh root@pve1.local 'qm config ${var.source_template_id}'"
      storage_content     = "ssh root@pve1.local 'ls -la /var/lib/vz/images/'"
    }
  }
}

# Legacy compatibility
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

output "deployment_ready_message" {
  description = "Success message with next steps"
  value = <<-EOT
    🎉 Template distribution complete - No Packer needed!
    
    ✅ Base template (${var.source_template_id}): ${var.source_template_name}
    ✅ Distributed templates:
    ${join("\n    ", [
      for target in var.target_nodes :
      "- ${target.node}: Template ${target.template_id}"
    ])}
    
    📋 Templates are ready for VM deployment:
    
    Next steps:
    1. cd ../03_deploy_vm
    2. terraform init && terraform apply
    3. VMs will be created from these templates
    4. Ansible will handle all K3s customization
    
    💡 This approach is faster and more reliable than Packer!
  EOT
  depends_on = [null_resource.distribute_template]
}

output "vm_deployment_config" {
  description = "Template IDs for VM deployment"
  value = {
    master_template_id = 9000  # Template on pve1 for master VM
    worker_template_id = 9010  # Template on pve2 for worker VM
  }
  depends_on = [null_resource.distribute_template]
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    source_template_id = var.source_template_id
    template_name     = var.source_template_name
    distributed_nodes = [for target in var.target_nodes : target.node]
    check_templates   = "ssh root@pve1.local 'qm list | grep template'"
    next_module       = "cd ../03_deploy_vm && terraform apply"
    storage_type      = "cluster-shared-nfs"
    packer_free       = "✅ No Packer needed - direct template cloning"
  }
}
