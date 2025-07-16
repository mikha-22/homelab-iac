# ===================================================================
#  TEMPLATE DISTRIBUTION - IMPROVED ERROR HANDLING
#  04_bootstrap_vm_nodes/02_template_distribution/main.tf
#  FIXED: Added template conversion after cloning
# ===================================================================

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
      set -euo pipefail  # ✅ EXIT ON ERROR
      
      echo "🔍 Checking source template ${var.source_template_id} disk location..."
      
      # ✅ IMPROVED: Retry logic with proper error handling
      for attempt in {1..3}; do
        if DISK_CONFIG=$(ssh ${local.ssh_opts} root@pve1.local "qm config ${var.source_template_id} | grep '^scsi0:'" 2>/dev/null); then
          break
        elif [[ $attempt -eq 3 ]]; then
          echo "❌ Failed to get template config after 3 attempts"
          echo "🔍 Debugging: Checking if template exists..."
          ssh ${local.ssh_opts} root@pve1.local "qm list | grep ${var.source_template_id}" || {
            echo "❌ Template ${var.source_template_id} does not exist on pve1"
            exit 1
          }
          exit 1
        else
          echo "⏳ Attempt $attempt failed, retrying in 5 seconds..."
          sleep 5
        fi
      done
      
      # ✅ IMPROVED: Better error messages and validation
      if [[ -z "$DISK_CONFIG" ]]; then
        echo "❌ Could not find scsi0 disk configuration for template ${var.source_template_id}"
        exit 1
      fi
      
      if [[ "$DISK_CONFIG" == *"cluster-shared-nfs:"* ]]; then
        echo "✅ Source template disk already on shared storage"
      elif [[ "$DISK_CONFIG" == *"local-lvm:"* ]]; then
        echo "📦 Moving source template disk to shared storage..."
        
        # ✅ IMPROVED: Validate shared storage exists before moving
        if ! ssh ${local.ssh_opts} root@pve1.local "pvesm status -storage cluster-shared-nfs" >/dev/null 2>&1; then
          echo "❌ Shared storage 'cluster-shared-nfs' not available on pve1"
          exit 1
        fi
        
        # ✅ IMPROVED: Move with proper error handling
        if ssh ${local.ssh_opts} root@pve1.local "qm disk move ${var.source_template_id} scsi0 cluster-shared-nfs --format qcow2"; then
          echo "✅ Source template disk moved to shared storage successfully"
        else
          echo "❌ Failed to move disk to shared storage"
          exit 1
        fi
      else
        echo "❌ Unknown disk configuration: $DISK_CONFIG"
        echo "🔍 Expected format: local-lvm: or cluster-shared-nfs:"
        exit 1
      fi
    EOT
  }
}

# ===================================================================
#  TEMPLATE DISTRIBUTION - IMPROVED ERROR HANDLING
# ===================================================================

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

  # ✅ IMPROVED: Comprehensive verification with retries
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      
      echo "🔍 Verifying source template ${var.source_template_id} on pve1..."
      
      # ✅ IMPROVED: Check template exists with better error messages
      for attempt in {1..3}; do
        if ssh ${local.ssh_opts} root@pve1.local "qm status ${var.source_template_id}" >/dev/null 2>&1; then
          echo "✅ Source template ${var.source_template_id} exists on pve1"
          break
        elif [[ $attempt -eq 3 ]]; then
          echo "❌ Source template ${var.source_template_id} not found on pve1 after 3 attempts"
          echo "🔍 Available templates:"
          ssh ${local.ssh_opts} root@pve1.local "qm list | grep template" || echo "No templates found"
          exit 1
        else
          echo "⏳ Template check attempt $attempt failed, retrying..."
          sleep 5
        fi
      done
      
      # ✅ IMPROVED: Verify it's actually a template
      if ! ssh ${local.ssh_opts} root@pve1.local "qm config ${var.source_template_id} | grep -q 'template: 1'"; then
        echo "❌ VM ${var.source_template_id} exists but is not marked as a template"
        echo "🔧 Converting to template first..."
        if ! ssh ${local.ssh_opts} root@pve1.local "qm template ${var.source_template_id}"; then
          echo "❌ Failed to convert VM to template"
          exit 1
        fi
        echo "✅ VM converted to template"
      fi
      
      # ✅ IMPROVED: Check target node connectivity
      if ! ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "echo 'connectivity test'" >/dev/null 2>&1; then
        echo "❌ Cannot connect to target node ${var.target_nodes[count.index].node}"
        exit 1
      fi
      
      echo "✅ Source template verified and target node accessible"
    EOT
  }

  # ✅ IMPROVED: Safer cleanup with existence checks
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      
      echo "🧹 Cleaning up existing template ${var.target_nodes[count.index].template_id} on ${var.target_nodes[count.index].node}..."
      
      # ✅ IMPROVED: Check if template exists before attempting to destroy
      if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "qm status ${var.target_nodes[count.index].template_id}" >/dev/null 2>&1; then
        echo "🗑️ Existing template found, removing..."
        if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "qm destroy ${var.target_nodes[count.index].template_id} --purge"; then
          echo "✅ Existing template removed successfully"
        else
          echo "⚠️ Failed to remove existing template, continuing anyway..."
        fi
      else
        echo "✅ No existing template to clean up"
      fi
    EOT
  }

  # ✅ IMPROVED: Clone with comprehensive error handling
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      
      echo "📦 Cloning template from pve1 to ${var.target_nodes[count.index].node}..."
      
      # ✅ IMPROVED: Verify shared storage is accessible on target
      if ! ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "pvesm status -storage cluster-shared-nfs" >/dev/null 2>&1; then
        echo "❌ Shared storage not accessible on ${var.target_nodes[count.index].node}"
        exit 1
      fi
      
      # ✅ IMPROVED: Clone with timeout and better error handling
      if timeout 300 ssh ${local.ssh_opts} root@pve1.local \
        "qm clone ${var.source_template_id} ${var.target_nodes[count.index].template_id} \
         --name '${var.source_template_name}-${var.target_nodes[count.index].node}' \
         --target ${var.target_nodes[count.index].node} \
         --full"; then
        echo "✅ Template cloned successfully"
      else
        echo "❌ Template clone failed or timed out (5 minutes)"
        exit 1
      fi
    EOT
  }

  # ✅ NEW: Convert cloned VM to template
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      
      echo "🔧 Converting cloned VM to template on ${var.target_nodes[count.index].node}..."
      
      # Wait for VM to be fully created
      sleep 10
      
      # Convert to template
      if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "qm template ${var.target_nodes[count.index].template_id}"; then
        echo "✅ VM ${var.target_nodes[count.index].template_id} converted to template on ${var.target_nodes[count.index].node}"
      else
        echo "❌ Failed to convert VM to template"
        exit 1
      fi
    EOT
  }

  # ✅ IMPROVED: Verification with detailed checks
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -euo pipefail
      
      echo "🔍 Verifying template creation on ${var.target_nodes[count.index].node}..."
      
      # ✅ IMPROVED: Wait for template to be ready
      for attempt in {1..12}; do
        if ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "qm status ${var.target_nodes[count.index].template_id}" >/dev/null 2>&1; then
          echo "✅ Template ${var.target_nodes[count.index].template_id} is ready on ${var.target_nodes[count.index].node}"
          break
        elif [[ $attempt -eq 12 ]]; then
          echo "❌ Template not ready after 2 minutes"
          exit 1
        else
          echo "⏳ Waiting for template to be ready... ($attempt/12)"
          sleep 10
        fi
      done
      
      # ✅ IMPROVED: Verify template configuration
      TEMPLATE_CONFIG=$(ssh ${local.ssh_opts} root@${var.target_nodes[count.index].node}.local "qm config ${var.target_nodes[count.index].template_id}")
      
      if echo "$TEMPLATE_CONFIG" | grep -q "scsi0:.*cluster-shared-nfs"; then
        echo "✅ Template has correct shared storage disk"
      else
        echo "❌ Template disk verification failed"
        echo "🔍 Template config:"
        echo "$TEMPLATE_CONFIG"
        exit 1
      fi
      
      if echo "$TEMPLATE_CONFIG" | grep -q "template: 1"; then
        echo "✅ VM is properly marked as template"
      else
        echo "❌ VM is not marked as template"
        exit 1
      fi
      
      echo "🎉 Template ${var.target_nodes[count.index].template_id} successfully verified on ${var.target_nodes[count.index].node}"
    EOT
  }
}
