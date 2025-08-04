module "shared" {
 source = "../../shared"
}

# Check if disk is already on shared storage and move if needed
resource "null_resource" "move_to_shared_storage" {
 triggers = {
   template_id = module.shared.vm_ids.base_template
 }

 provisioner "local-exec" {
   command = <<-EOT
     # Check if already on shared storage
     if ssh -o StrictHostKeyChecking=no root@pve1.local "qm config ${module.shared.vm_ids.base_template} | grep -q 'scsi0: cluster-shared-nfs'"; then
       echo "Disk already on shared storage, skipping move"
     else
       echo "Moving disk to shared storage"
       ssh -o StrictHostKeyChecking=no root@pve1.local \
         "qm disk move ${module.shared.vm_ids.base_template} scsi0 cluster-shared-nfs --format qcow2"
     fi
   EOT
 }
}

# Clone to pve1 (template 9000)
resource "null_resource" "clone_to_pve1" {
 depends_on = [null_resource.move_to_shared_storage]
 
 provisioner "local-exec" {
   command = <<-EOT
     if ! ssh -o StrictHostKeyChecking=no root@pve1.local "qm status 9000 >/dev/null 2>&1"; then
       echo "Creating template 9000 on pve1"
       ssh -o StrictHostKeyChecking=no root@pve1.local "
         qm clone ${module.shared.vm_ids.base_template} 9000 --name ubuntu-2404-base-pve1 --full
         qm template 9000
       "
     else
       echo "Template 9000 already exists on pve1"
     fi
   EOT
 }
}

# Clone to pve2 (template 9010)
resource "null_resource" "clone_to_pve2" {
 depends_on = [null_resource.move_to_shared_storage]
 
 provisioner "local-exec" {
   command = <<-EOT
     if ! ssh -o StrictHostKeyChecking=no root@pve2.local "qm status 9010 >/dev/null 2>&1"; then
       echo "Creating template 9010 on pve2"
       ssh -o StrictHostKeyChecking=no root@pve1.local \
         "qm clone ${module.shared.vm_ids.base_template} 9010 --name ubuntu-2404-base-pve2 --target pve2 --full"
       ssh -o StrictHostKeyChecking=no root@pve2.local "qm template 9010"
     else
       echo "Template 9010 already exists on pve2"
     fi
   EOT
 }
}
