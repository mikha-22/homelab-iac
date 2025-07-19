module "shared" {
  source = "../../shared"
}

# Move base template to shared storage
resource "null_resource" "move_to_shared_storage" {
  triggers = {
    template_id = module.shared.vm_ids.base_template
  }

  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@pve1.local \
        "qm disk move ${module.shared.vm_ids.base_template} scsi0 cluster-shared-nfs --format qcow2"
    EOT
  }
}

# Clone to pve1 (template 9000)
resource "null_resource" "clone_to_pve1" {
  depends_on = [null_resource.move_to_shared_storage]
  
  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@pve1.local "
        qm clone ${module.shared.vm_ids.base_template} 9000 --name ubuntu-2404-base-pve1 --full
        qm template 9000
      "
    EOT
  }
}

# Clone to pve2 (template 9010) 
resource "null_resource" "clone_to_pve2" {
  depends_on = [null_resource.move_to_shared_storage]
  
  provisioner "local-exec" {
    command = <<-EOT
      ssh -o StrictHostKeyChecking=no root@pve1.local \
        "qm clone ${module.shared.vm_ids.base_template} 9010 --name ubuntu-2404-base-pve2 --target pve2 --full"
      ssh -o StrictHostKeyChecking=no root@pve2.local "qm template 9010"
    EOT
  }
}
