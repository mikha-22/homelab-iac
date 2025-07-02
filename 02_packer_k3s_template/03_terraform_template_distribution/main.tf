# ===================================================================
#  PROJECT: TEMPLATE DISTRIBUTION
#  Distributes golden image templates to all Proxmox nodes
#  Run this after Packer creates the golden template on pve1
# ===================================================================

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

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

# --- TEMPLATE DISTRIBUTION ---
resource "null_resource" "distribute_template" {
  count = length(var.target_nodes)

  triggers = {
    # Re-run if source template changes or target configuration changes
    source_template_id = var.source_template_id
    target_node       = var.target_nodes[count.index].node
    target_template_id = var.target_nodes[count.index].template_id
    # Store values needed for destroy in triggers
    ssh_key_path      = var.ssh_key_path
    ssh_opts          = "-i ${var.ssh_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
    # Add timestamp to force re-run when needed
    timestamp = timestamp()
  }

  # Verify source template exists
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔍 Verifying source template ${var.source_template_id} exists on pve1..."
      if ! ssh ${local.ssh_opts} root@pve1.local "qm status ${var.source_template_id}" >/dev/null 2>&1; then
        echo "❌ Source template ${var.source_template_id} not found on pve1"
        echo "Please run Packer first to create the golden template"
        exit 1
      fi
      echo "✅ Source template verified"
    EOT
  }

  # Remove existing template on target node
  provisioner "local-exec" {
    command = <<-EOT
      echo "🧹 Cleaning up existing template ${var.target_nodes[count.index].template_id} on ${var.target_nodes[count.index].node}..."
      ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
        "qm destroy ${var.target_nodes[count.index].template_id} --purge 2>/dev/null || true"
    EOT
  }

  # Get source template configuration
  provisioner "local-exec" {
    command = <<-EOT
      echo "📋 Getting template configuration from pve1..."
      ssh ${local.ssh_opts} root@pve1.local "qm config ${var.source_template_id}" > /tmp/template_config_${count.index}.txt
    EOT
  }

  # Create new VM on target node
  provisioner "local-exec" {
    command = <<-EOT
      echo "🔧 Creating VM ${var.target_nodes[count.index].template_id} on ${var.target_nodes[count.index].node}..."
      ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
        "qm create ${var.target_nodes[count.index].template_id} --name '${var.source_template_name}-${var.target_nodes[count.index].node}'"
    EOT
  }

  # Apply configuration from source template
  provisioner "local-exec" {
    command = <<-EOT
      echo "⚙️ Applying configuration to ${var.target_nodes[count.index].node}..."
      
      # Read the config file and apply settings
      while IFS=': ' read -r key value; do
        case "$key" in
          "cores")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --cores $value" 2>/dev/null || true
            ;;
          "memory")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --memory $value" 2>/dev/null || true
            ;;
          "scsihw")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --scsihw $value" 2>/dev/null || true
            ;;
          "scsi0")
            # Replace local-lvm with cluster-shared-nfs for cross-node access
            DISK_CONFIG=$(echo "$value" | sed 's/local-lvm:/cluster-shared-nfs:/')
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --scsi0 '$DISK_CONFIG'" 2>/dev/null || true
            ;;
          "ide2")
            # Replace local-lvm with cluster-shared-nfs for cloud-init
            CLOUDINIT_CONFIG=$(echo "$value" | sed 's/local-lvm:/cluster-shared-nfs:/')
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --ide2 '$CLOUDINIT_CONFIG'" 2>/dev/null || true
            ;;
          "net0")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --net0 '$value'" 2>/dev/null || true
            ;;
          "agent")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --agent '$value'" 2>/dev/null || true
            ;;
          "boot")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --boot '$value'" 2>/dev/null || true
            ;;
          "cpu")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --cpu '$value'" 2>/dev/null || true
            ;;
          "numa")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --numa $value" 2>/dev/null || true
            ;;
          "tablet")
            ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
              "qm set ${var.target_nodes[count.index].template_id} --tablet $value" 2>/dev/null || true
            ;;
        esac
      done < /tmp/template_config_${count.index}.txt
    EOT
  }

  # Convert to template
  provisioner "local-exec" {
    command = <<-EOT
      echo "🎯 Converting VM to template on ${var.target_nodes[count.index].node}..."
      ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
        "qm template ${var.target_nodes[count.index].template_id}"
    EOT
  }

  # Verification
  provisioner "local-exec" {
    command = <<-EOT
      echo "✅ Verifying template creation on ${var.target_nodes[count.index].node}..."
      if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local \
         "qm list | grep -q '${var.target_nodes[count.index].template_id}.*template'"; then
        echo "✅ Template ${var.target_nodes[count.index].template_id} successfully created on ${var.target_nodes[count.index].node}"
      else
        echo "❌ Template verification failed on ${var.target_nodes[count.index].node}"
        exit 1
      fi
    EOT
  }

  # Cleanup temp files
  provisioner "local-exec" {
    command = "rm -f /tmp/template_config_${count.index}.txt"
  }

  # --- DESTROY PROVISIONER (Fixed to use self.triggers) ---
  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "🗑️ Destroying template ${self.triggers.target_template_id} on ${self.triggers.target_node}..."
      ssh ${self.triggers.ssh_opts} root@${self.triggers.target_node}.local \
        "qm destroy ${self.triggers.target_template_id} --purge 2>/dev/null || true"
      echo "✅ Template cleanup complete on ${self.triggers.target_node}"
    EOT
  }

  # Cleanup temp files on destroy
  provisioner "local-exec" {
    when = destroy
    command = "rm -f /tmp/template_config_${count.index}.txt"
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
    }
    targets = [
      for i, target in var.target_nodes : {
        node        = target.node
        template_id = target.template_id
        name        = "${var.source_template_name}-${target.node}"
      }
    ]
  }
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
}
