# ===================================================================
#  SHARED NETWORK CONFIGURATION - CLEAN VERSION
# ===================================================================

locals {
  # Core network settings
  network = {
    subnet      = local.final_network.subnet
    gateway     = local.final_network.gateway
    cidr        = "${local.final_network.subnet}.0/24"
    dns_servers = local.final_network.dns_servers
    domain      = local.final_network.domain
    
    # Infrastructure IPs
    nas_server    = "${local.final_network.subnet}.225"
    k3s_master    = "${local.final_network.subnet}.181"
    k3s_worker_01 = "${local.final_network.subnet}.182"
  }
  
  # GCP Project configuration
  gcp = {
    project_id = var.gcp_project_id
    region     = var.gcp_region
  }
  
  # VM ID assignments
  vm_ids = {
    base_template   = var.vm_id_overrides.base_template
    master_template = var.vm_id_overrides.master_template
    worker_template = var.vm_id_overrides.worker_template
    nas_server      = var.vm_id_overrides.nas_server
    k3s_master      = var.vm_id_overrides.k3s_master
    k3s_worker_01   = var.vm_id_overrides.k3s_worker_01
  }
  
  # VM configurations
  vm_configs = local.final_vm_configs
  
  # Tagging
  common_tags = ["homelab", "terraform-managed", "environment-${var.environment_size}"]
  
  role_tags = {
    nas        = ["nas", "nfs", "storage", "infrastructure"]
    k3s_master = ["k3s", "master", "control-plane", "kubernetes"]
    k3s_worker = ["k3s", "worker", "compute", "kubernetes"]
    template   = ["template", "base-image"]
  }
  
  # Service hostnames
  services = {
    argocd   = "argocd.${local.network.domain}"
    grafana  = "grafana.${local.network.domain}"
  }
  
  # Full IP addresses for easy reference
  full_ips = {
    nas_server    = "${local.network.nas_server}/24"
    k3s_master    = "${local.network.k3s_master}/24"
    k3s_worker_01 = "${local.network.k3s_worker_01}/24"
  }
  
  # SSH connection strings
  ssh_commands = {
    nas_server = "ssh mikha@${local.network.nas_server}"
    k3s_master = "ssh ubuntu@${local.network.k3s_master}"
    k3s_worker = "ssh ubuntu@${local.network.k3s_worker_01}"
  }
}

# ===================================================================
#  ESSENTIAL VALIDATION ONLY
# ===================================================================

check "ip_subnet_validation" {
  assert {
    condition = alltrue([
      startswith(local.network.nas_server, "${local.network.subnet}."),
      startswith(local.network.k3s_master, "${local.network.subnet}."),
      startswith(local.network.k3s_worker_01, "${local.network.subnet}."),
      startswith(local.network.gateway, "${local.network.subnet}.")
    ])
    error_message = "All IP addresses must be in the ${local.network.subnet}.x subnet."
  }
}

check "ip_uniqueness" {
  assert {
    condition = length([
      local.network.nas_server,
      local.network.k3s_master,
      local.network.k3s_worker_01,
      local.network.gateway
    ]) == length(toset([
      local.network.nas_server,
      local.network.k3s_master,
      local.network.k3s_worker_01,
      local.network.gateway
    ]))
    error_message = "All IP addresses must be unique."
  }
}

check "vm_resource_minimums" {
  assert {
    condition = alltrue([
      local.vm_configs.k3s_master.memory >= 4096,
      local.vm_configs.k3s_worker.memory >= 4096
    ])
    error_message = "K3s nodes require at least 4GB RAM for stable operation."
  }
}
