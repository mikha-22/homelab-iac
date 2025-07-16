# ===================================================================
#  TEMPLATE DISTRIBUTION - CLEAN VERSION
# ===================================================================

module "shared" {
  source = "../../shared"
}

resource "null_resource" "move_source_to_shared_storage" {
  triggers = {
    source_template_id = module.shared.vm_ids.base_template
    ssh_key_content   = module.shared.proxmox_ssh_private_key
    timestamp         = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Checking source template ${module.shared.vm_ids.base_template} disk location..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      for attempt in {1..3}; do
        if DISK_CONFIG=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local "qm config ${module.shared.vm_ids.base_template} | grep '^scsi0:'" 2>/dev/null); then
          break
        elif [[ $attempt -eq 3 ]]; then
          echo "Failed to get template config after 3 attempts"
          rm -f "$TMP_KEY"
          exit 1
        else
          echo "Attempt $attempt failed, retrying in 5 seconds..."
          sleep 5
        fi
      done
      
      if [[ "$DISK_CONFIG" == *"cluster-shared-nfs:"* ]]; then
        echo "Source template disk already on shared storage"
      elif [[ "$DISK_CONFIG" == *"local-lvm:"* ]]; then
        echo "Moving source template disk to shared storage..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local "qm disk move ${module.shared.vm_ids.base_template} scsi0 cluster-shared-nfs --format qcow2"
        echo "Source template disk moved to shared storage"
      fi
      
      rm -f "$TMP_KEY"
    EOT
  }
}

resource "null_resource" "distribute_template" {
  count = length(var.target_nodes)
  depends_on = [null_resource.move_source_to_shared_storage]

  triggers = {
    source_template_id = module.shared.vm_ids.base_template
    target_node       = var.target_nodes[count.index].node
    target_template_id = var.target_nodes[count.index].template_id
    ssh_key_content   = module.shared.proxmox_ssh_private_key
    timestamp         = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Verifying source template ${module.shared.vm_ids.base_template} on pve1..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      for attempt in {1..3}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local "qm status ${module.shared.vm_ids.base_template}" >/dev/null 2>&1; then
          echo "Source template ${module.shared.vm_ids.base_template} exists on pve1"
          break
        elif [[ $attempt -eq 3 ]]; then
          echo "Source template ${module.shared.vm_ids.base_template} not found on pve1 after 3 attempts"
          rm -f "$TMP_KEY"
          exit 1
        else
          echo "Template check attempt $attempt failed, retrying..."
          sleep 5
        fi
      done
      
      if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local "qm config ${module.shared.vm_ids.base_template} | grep -q 'template: 1'"; then
        echo "Converting VM to template first..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local "qm template ${module.shared.vm_ids.base_template}"
        echo "VM converted to template"
      fi
      
      rm -f "$TMP_KEY"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Cleaning up existing template ${var.target_nodes[count.index].template_id} on ${var.target_nodes[count.index].node}..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "qm status ${var.target_nodes[count.index].template_id}" >/dev/null 2>&1; then
        echo "Removing existing template..."
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "qm destroy ${var.target_nodes[count.index].template_id} --purge" || echo "Failed to remove existing template, continuing anyway..."
      else
        echo "No existing template to clean up"
      fi
      
      rm -f "$TMP_KEY"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Cloning template from pve1 to ${var.target_nodes[count.index].node}..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      if ! ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "pvesm status -storage cluster-shared-nfs" >/dev/null 2>&1; then
        echo "Shared storage not accessible on ${var.target_nodes[count.index].node}"
        rm -f "$TMP_KEY"
        exit 1
      fi
      
      if timeout 300 ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@pve1.local \
        "qm clone ${module.shared.vm_ids.base_template} ${var.target_nodes[count.index].template_id} \
         --name '${var.source_template_name}-${var.target_nodes[count.index].node}' \
         --target ${var.target_nodes[count.index].node} \
         --full"; then
        echo "Template cloned successfully"
      else
        echo "Template clone failed or timed out"
        rm -f "$TMP_KEY"
        exit 1
      fi
      
      rm -f "$TMP_KEY"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Converting cloned VM to template on ${var.target_nodes[count.index].node}..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      sleep 10
      
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "qm template ${var.target_nodes[count.index].template_id}"
      echo "VM ${var.target_nodes[count.index].template_id} converted to template on ${var.target_nodes[count.index].node}"
      
      rm -f "$TMP_KEY"
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      set -e
      
      echo "Verifying template creation on ${var.target_nodes[count.index].node}..."
      
      TMP_KEY=$(mktemp)
      echo "${module.shared.proxmox_ssh_private_key}" > "$TMP_KEY"
      chmod 600 "$TMP_KEY"
      
      for attempt in {1..12}; do
        if ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "qm status ${var.target_nodes[count.index].template_id}" >/dev/null 2>&1; then
          echo "Template ${var.target_nodes[count.index].template_id} is ready on ${var.target_nodes[count.index].node}"
          break
        elif [[ $attempt -eq 12 ]]; then
          echo "Template not ready after 2 minutes"
          rm -f "$TMP_KEY"
          exit 1
        else
          echo "Waiting for template to be ready... ($attempt/12)"
          sleep 10
        fi
      done
      
      TEMPLATE_CONFIG=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "$TMP_KEY" root@${var.target_nodes[count.index].node}.local "qm config ${var.target_nodes[count.index].template_id}")
      
      if echo "$TEMPLATE_CONFIG" | grep -q "scsi0:.*cluster-shared-nfs"; then
        echo "Template has correct shared storage disk"
      else
        echo "Template disk verification failed"
        rm -f "$TMP_KEY"
        exit 1
      fi
      
      if echo "$TEMPLATE_CONFIG" | grep -q "template: 1"; then
        echo "VM is properly marked as template"
      else
        echo "VM is not marked as template"
        rm -f "$TMP_KEY"
        exit 1
      fi
      
      rm -f "$TMP_KEY"
      
      echo "Template ${var.target_nodes[count.index].template_id} successfully verified on ${var.target_nodes[count.index].node}"
    EOT
  }
}
