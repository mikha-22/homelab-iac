# ===================================================================
#  PROJECT: TEMPLATE DISTRIBUTION - FIXED VERSION
#  Properly distributes golden image templates to all Proxmox nodes
#  FIXED: Now actually copies disk data, not just config references
# ===================================================================

# --- VARIABLES ---
variable "ssh_key_path" {
  description = "Path to SSH private key for Proxmox authentication"
  type        = string
  default     = "~/.ssh/proxmox_key"
}

variable "source_template_id" {
  description = "Source template ID on pve1"
  type        = number
  default     = 9000
}

variable "source_template_name" {
  description = "Name of the source template"
  type        = string
  default     = "ubuntu-2404-k3s-template"
}

variable "target_nodes" {
  description = "Target nodes to copy template to"
  type = list(object({
    node        = string
    template_id = number
  }))
  default = [
    {
      node        = "pve2"
      template_id = 9010
    }
  ]
}

# --- LOCAL VALUES ---
locals {
  ssh_opts = "-i ${var.ssh_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
}

# --- STEP 1: MOVE SOURCE TEMPLATE TO SHARED STORAGE ---
resource "null_resource" "move_source_to_shared_storage" {
  triggers = {
    source_template_id = var.source_template_id
    ssh_key_path      = var.ssh_key_path
    ssh_opts          = local.ssh_opts
    timestamp         = timestamp()
  }

  # Check if source template disk is already on shared storage
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🔍 Checking source template ${var.source_template_id} disk location..."
      
      DISK_CONFIG=$(ssh ${local.ssh_opts} root@pve1.local "qm config ${var.source_template_id} | grep '^scsi0:'" || echo "")
      
      if [[ "$DISK_CONFIG" == *"cluster-shared-nfs:"* ]]; then
        echo "✅ Source template disk already on shared storage"
      elif [[ "$DISK_CONFIG" == *"local-lvm:"* ]]; then
        echo "📦 Moving source template disk to shared storage..."
        ssh ${local.ssh_opts} root@pve1.local "qm disk move ${var.source_template_id} scsi0 cluster-shared-nfs --format qcow2"
        echo "✅ Source template disk moved to shared storage"
      else
        echo "❌ Could not determine source template disk location"
        echo "Disk config: $DISK_CONFIG"
        exit 1
      fi
    EOT
  }

  # Cleanup on destroy
  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "ℹ️  Note: Source template disk remains on shared storage for reuse"
    EOT
  }
}

# --- STEP 2: DISTRIBUTE TEMPLATE TO TARGET NODES ---
resource "null_resource" "distribute_template" {
  count = length(var.target_nodes)

  depends_on = [null_resource.move_source_to_shared_storage]

  triggers = {
    source_template_id = var.source_template_id
    target_node       = var.target_nodes[count.index].node
    target_template_id = var.target_nodes[count.index].template_id
    ssh_key_path      = var.ssh_key_path
    ssh_opts          = local.ssh_opts
    timestamp         = timestamp()
  }

  # Verify source template exists and is accessible
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🔍 Verifying source template ${var.source_template_id} on pve1..."
      if ! ssh ${local.ssh_opts} root@pve1.local "qm status ${var.source_template_id}" >/dev/null 2>&1; then
        echo "❌ Source template ${var.source_template_id} not found on pve1"
        exit 1
      fi
      
      if ! ssh ${local.ssh_opts} root@pve1.local "qm config ${var.source_template_id} | grep -q 'template: 1'"; then
        echo "❌ VM ${var.source_template_id} is not a template"
        exit 1
      fi
      
      echo "✅ Source template verified"
    EOT
  }

  # Remove existing template on target node if it exists
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🧹 Cleaning up existing template ${var.target_nodes[count.index].template_id} on ${var.target_nodes[count.index].node}..."
      ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
        "qm destroy ${var.target_nodes[count.index].template_id} --purge 2>/dev/null || true"
      echo "✅ Cleanup complete"
    EOT
  }

  # Clone template from pve1 to target node using proper cross-node clone
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "📦 Cloning template from pve1 to ${var.target_nodes[count.index].node}..."
      
      # Use qm clone with --target to properly copy across nodes
      ssh ${local.ssh_opts} root@pve1.local \
        "qm clone ${var.source_template_id} ${var.target_nodes[count.index].template_id} \
         --name '${var.source_template_name}-${var.target_nodes[count.index].node}' \
         --target ${var.target_nodes[count.index].node} \
         --full"
      
      echo "✅ Template cloned successfully"
    EOT
  }

  # Convert cloned VM to template (if not already)
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🎯 Converting VM to template on ${var.target_nodes[count.index].node}..."
      
      # Check if it's already a template
      if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
         "qm config ${var.target_nodes[count.index].template_id} | grep -q 'template: 1'"; then
        echo "✅ VM is already a template"
      else
        ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
          "qm template ${var.target_nodes[count.index].template_id}"
        echo "✅ VM converted to template"
      fi
    EOT
  }

  # Verification
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🔍 Verifying template creation on ${var.target_nodes[count.index].node}..."
      
      # Check template exists and has proper disk
      if ! ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
         "qm config ${var.target_nodes[count.index].template_id} | grep -q 'scsi0:.*cluster-shared-nfs'"; then
        echo "❌ Template verification failed - no proper disk found"
        exit 1
      fi
      
      if ! ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
         "qm config ${var.target_nodes[count.index].template_id} | grep -q 'template: 1'"; then
        echo "❌ Template verification failed - not marked as template"
        exit 1
      fi
      
      echo "✅ Template ${var.target_nodes[count.index].template_id} successfully verified on ${var.target_nodes[count.index].node}"
    EOT
  }

  # Destroy provisioner
  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🗑️ Destroying template ${self.triggers.target_template_id} on ${self.triggers.target_node}..."
      ssh ${self.triggers.ssh_opts} root@${self.triggers.target_node}.local \
        "qm destroy ${self.triggers.target_template_id} --purge 2>/dev/null || true"
      echo "✅ Template cleanup complete on ${self.triggers.target_node}"
    EOT
  }
}

# --- OUTPUTS ---
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
