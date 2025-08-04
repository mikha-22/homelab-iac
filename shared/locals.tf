locals {
  # === INFRASTRUCTURE CONFIGURATION ===
  # Edit these values to customize your homelab
  
  # Network Settings
  network_config = {
    subnet      = "192.168.1"
    gateway_ip  = 1
    domain      = "milenika.dev"
    dns_servers = ["1.1.1.1", "8.8.8.8"]
  }
  
  # VM Resource Allocations
  vm_resources = {
    nas = {
      cores  = 1
      memory = 2048  # 2GB
      disk   = 100   # GB
    }
    k3s_master = {
      cores  = 8
      memory = 8192  # 8GB
      disk   = 40    # GB
    }
    k3s_worker = {
      cores  = 12
      memory = 16384  # 16GB
      disk   = 40    # GB
    }
  }
  
  # VM ID Assignments
  vm_ids = {
    base_template   = 9999
    master_template = 9000
    worker_template = 9010
    nas_server      = 225
    k3s_master      = 181
    k3s_worker_01   = 182
  }
  
  # IP Address Assignments (last octet)
  ip_assignments = {
    nas_server    = 225
    k3s_master    = 181
    k3s_worker_01 = 182
  }
  
  # === DERIVED VALUES (Don't edit these) ===
  network = {
    subnet      = local.network_config.subnet
    gateway     = "${local.network_config.subnet}.${local.network_config.gateway_ip}"
    domain      = local.network_config.domain
    dns_servers = local.network_config.dns_servers
    
    # IP addresses
    nas_server    = "${local.network_config.subnet}.${local.ip_assignments.nas_server}"
    k3s_master    = "${local.network_config.subnet}.${local.ip_assignments.k3s_master}"
    k3s_worker_01 = "${local.network_config.subnet}.${local.ip_assignments.k3s_worker_01}"
  }
  
  # Full IP addresses with CIDR
  full_ips = {
    nas_server    = "${local.network.nas_server}/24"
    k3s_master    = "${local.network.k3s_master}/24"
    k3s_worker_01 = "${local.network.k3s_worker_01}/24"
  }
  
  # Use the centralized VM resources
  vm_configs = local.vm_resources
  
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
