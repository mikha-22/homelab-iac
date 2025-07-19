# ===================================================================
#  SHARED MODULE: LOCAL VALUES
# ===================================================================

locals {
  # Network configuration
  network = {
    subnet      = var.network_subnet
    gateway     = "${var.network_subnet}.${var.gateway_ip}"
    domain      = var.domain
    dns_servers = ["1.1.1.1", "8.8.8.8"]
    
    # IP addresses
    nas_server    = "${var.network_subnet}.${var.nas_ip}"
    k3s_master    = "${var.network_subnet}.${var.k3s_master_ip}"
    k3s_worker_01 = "${var.network_subnet}.${var.k3s_worker_ip}"
  }
  
  # Full IP addresses with CIDR
  full_ips = {
    nas_server    = "${local.network.nas_server}/24"
    k3s_master    = "${local.network.k3s_master}/24"
    k3s_worker_01 = "${local.network.k3s_worker_01}/24"
  }
  
  # VM configurations
  vm_configs = {
    nas = {
      cores  = var.nas_cores
      memory = var.nas_memory
      disk   = 50
    }
    k3s_master = {
      cores  = var.k3s_cores
      memory = var.k3s_memory
      disk   = 20
    }
    k3s_worker = {
      cores  = var.k3s_cores
      memory = var.k3s_memory
      disk   = 20
    }
  }
  
  # VM IDs
  vm_ids = {
    base_template   = var.base_template_id
    master_template = 9000
    worker_template = 9010
    nas_server      = var.nas_vm_id
    k3s_master      = var.k3s_master_vm_id
    k3s_worker_01   = var.k3s_worker_vm_id
  }
  
  # Simple tags
  common_tags = ["homelab", "terraform"]
  
  role_tags = {
    nas        = ["nas", "storage"]
    k3s_master = ["k3s", "master"]
    k3s_worker = ["k3s", "worker"]
  }
  
  # SSH commands for convenience
  ssh_commands = {
    nas_server = "ssh mikha@${local.network.nas_server}"
    k3s_master = "ssh ubuntu@${local.network.k3s_master}"
    k3s_worker = "ssh ubuntu@${local.network.k3s_worker_01}"
  }
}
