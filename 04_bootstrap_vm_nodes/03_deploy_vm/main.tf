# ===================================================================
#  K3S VM DEPLOYMENT - CLEAN VERSION
# ===================================================================

module "shared" {
  source = "../../shared"
}

data "terraform_remote_state" "base_template" {
  backend = "gcs"
  config = {
    bucket = "homelab-terraform-state-shared"
    prefix = "04_bootstrap_vm_nodes/01_download_base_image"
  }
}

locals {
  master_init_content = templatefile("${path.module}/master-init.yaml", {
    user_ssh_public_key = module.shared.nas_ssh_public_key
  })
  worker_init_content = templatefile("${path.module}/worker-init.yaml", {
    user_ssh_public_key = module.shared.nas_ssh_public_key
  })
}

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve1"

  source_raw {
    file_name = "master-hostname-init.yaml"
    data      = local.master_init_content
  }
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  content_type = "snippets"
  datastore_id = "cluster-shared-nfs"
  node_name    = "pve2"

  source_raw {
    file_name = "worker-hostname-init.yaml"
    data      = local.worker_init_content
  }
}

resource "proxmox_virtual_environment_vm" "master" {
  name      = "dev-k3s-master-01"
  node_name = "pve1"
  vm_id     = module.shared.vm_ids.k3s_master
  tags      = concat(module.shared.common_tags, module.shared.role_tags.k3s_master)

  depends_on = [proxmox_virtual_environment_file.master_cloud_init]

  clone {
    vm_id        = 9000
    full         = true
    datastore_id = "cluster-shared-nfs"
  }

  cpu {
    cores = module.shared.vm_configs.k3s_master.cores
    type  = "host"
  }
  memory { dedicated = module.shared.vm_configs.k3s_master.memory }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.master_cloud_init.id
    dns { servers = module.shared.dns_servers }
    ip_config {
      ipv4 {
        address = module.shared.full_ips.k3s_master
        gateway = module.shared.gateway
      }
    }
  }
}

resource "proxmox_virtual_environment_vm" "worker" {
  name      = "dev-k3s-worker-01"
  node_name = "pve2"
  vm_id     = module.shared.vm_ids.k3s_worker_01
  tags      = concat(module.shared.common_tags, module.shared.role_tags.k3s_worker)

  depends_on = [proxmox_virtual_environment_file.worker_cloud_init]

  clone {
    vm_id        = 9010
    full         = true
    datastore_id = "cluster-shared-nfs"
  }

  cpu {
    cores = module.shared.vm_configs.k3s_worker.cores
    type  = "host"
  }
  memory { dedicated = module.shared.vm_configs.k3s_worker.memory }
  agent { enabled = true }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  initialization {
    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init.id
    dns { servers = module.shared.dns_servers }
    ip_config {
      ipv4 {
        address = module.shared.full_ips.k3s_worker_01
        gateway = module.shared.gateway
      }
    }
  }
}

resource "null_resource" "verify_cluster_ready" {
  depends_on = [
    proxmox_virtual_environment_vm.master,
    proxmox_virtual_environment_vm.worker
  ]

  triggers = {
    master_ip = module.shared.network.k3s_master
    worker_ip = module.shared.network.k3s_worker_01
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = <<-EOT
      for ip in ${module.shared.network.k3s_master} ${module.shared.network.k3s_worker_01}; do
        echo "Waiting for $ip..."
        timeout 120 bash -c "while ! ping -c 1 $ip >/dev/null 2>&1; do sleep 5; done"
        echo "$ip is ready"
      done
    EOT
  }
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../../05_k3s_ansible_bootstrap/inventory.yml.tpl", {
    master_ip    = module.shared.network.k3s_master
    worker_ip    = module.shared.network.k3s_worker_01
    master_vm_id = module.shared.vm_ids.k3s_master
    worker_vm_id = module.shared.vm_ids.k3s_worker_01
    k3s_token    = module.shared.k3s_cluster_token
    subnet       = module.shared.network.subnet
    nas_ip       = module.shared.network.nas_server
    gateway      = module.shared.gateway
    domain       = module.shared.domain
  })

  filename = "${path.module}/../../05_k3s_ansible_bootstrap/inventory.yml"

  depends_on = [
    null_resource.verify_cluster_ready
  ]
}
