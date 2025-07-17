# ===================================================================
#  SIMPLIFIED TEMPLATE DISTRIBUTION - FIXED FOR SHARED STORAGE
# ===================================================================

module "shared" {
  source = "../../shared"
}

# Clone template to pve1 (local storage)
resource "null_resource" "clone_template_to_pve1" {
  triggers = {
    template_id = module.shared.vm_ids.base_template
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@pve1.local "
        qm clone ${module.shared.vm_ids.base_template} 9000 --name ubuntu-2404-base-pve1 --full
        qm template 9000
      "
    EOT
  }
}

# Clone template to pve2 using shared storage
resource "null_resource" "clone_template_to_pve2" {
  triggers = {
    template_id = module.shared.vm_ids.base_template
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@pve1.local "
        qm clone ${module.shared.vm_ids.base_template} 9010 --name ubuntu-2404-base-pve2 --target pve2 --full --storage cluster-shared-nfs
      "
      ssh -o StrictHostKeyChecking=no root@pve2.local "qm template 9010"
    EOT
  }
}
