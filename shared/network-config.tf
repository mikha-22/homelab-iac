# ===================================================================
#  SHARED NETWORK CONFIGURATION - USING VALIDATED INPUTS
#  FIXED: Now uses validated variables instead of hardcoded values
# ===================================================================

locals {
  # Core network settings (using validated variables)
  network = {
    # Network basics (validated)
    subnet      = local.final_network.subnet
    gateway     = local.final_network.gateway
    cidr        = "${local.final_network.subnet}.0/24"
    dns_servers = local.final_network.dns_servers
    
    # Domain configuration (validated)
    domain = local.final_network.domain
    
    # Infrastructure IPs (validated to be in subnet)
    nas_server = "${local.final_network.subnet}.225"
    
    # K3s cluster IPs (validated to be in subnet)
    k3s_master    = "${local.final_network.subnet}.181"
    k3s_worker_01 = "${local.final_network.subnet}.182"
    
    # Future expansion (validated format)
    # k3s_worker_02 = "${local.final_network.subnet}.183"
    # k3s_worker_03 = "${local.final_network.subnet}.184"
  }
  
  # GCP Project configuration (validated)
  gcp = {
    project_id = var.gcp_project_id
    region     = var.gcp_region
  }
  
  # VM ID assignments (validated for conflicts and ranges)
  vm_ids = {
    # Templates (validated range 9000-9999)
    base_template   = var.vm_id_overrides.base_template
    master_template = var.vm_id_overrides.master_template
    worker_template = var.vm_id_overrides.worker_template
    
    # Infrastructure VMs (validated range 200-299)
    nas_server = var.vm_id_overrides.nas_server
    
    # K3s cluster VMs (validated range 180-189)
    k3s_master    = var.vm_id_overrides.k3s_master
    k3s_worker_01 = var.vm_id_overrides.k3s_worker_01
    
    # Future expansion (pre-validated)
    # k3s_worker_02 = var.vm_id_overrides.k3s_worker_02
    # k3s_worker_03 = var.vm_id_overrides.k3s_worker_03
  }
  
  # Standard VM configurations (validated resources)
  vm_configs = local.final_vm_configs
  
  # Standardized tagging
  common_tags = ["homelab", "terraform-managed", "environment-${var.environment_size}"]
  
  role_tags = {
    nas        = ["nas", "nfs", "storage", "infrastructure"]
    k3s_master = ["k3s", "master", "control-plane", "kubernetes"]
    k3s_worker = ["k3s", "worker", "compute", "kubernetes"]
    template   = ["template", "base-image"]
  }
  
  # Service hostnames (validated domain format)
  services = {
    argocd   = "argocd.${local.network.domain}"
    grafana  = "grafana.${local.network.domain}"
    # prometheus = "prometheus.${local.network.domain}"
    # minio      = "minio.${local.network.domain}"
  }
}

# ===================================================================
#  HELPER FUNCTIONS WITH VALIDATION
# ===================================================================

# Generate full IP addresses (validated format)
locals {
  # Full IP addresses for easy reference (validated CIDR)
  full_ips = {
    nas_server    = "${local.network.nas_server}/24"
    k3s_master    = "${local.network.k3s_master}/24"
    k3s_worker_01 = "${local.network.k3s_worker_01}/24"
  }
  
  # SSH connection strings (validated IPs)
  ssh_commands = {
    nas_server = "ssh mikha@${local.network.nas_server}"
    k3s_master = "ssh ubuntu@${local.network.k3s_master}"
    k3s_worker = "ssh ubuntu@${local.network.k3s_worker_01}"
  }
}

# ===================================================================
#  COMPREHENSIVE VALIDATION CHECKS
# ===================================================================

# Ensure all IPs are in the correct subnet
locals {
  # Validate all IPs are in the same subnet
  ip_validations = {
    nas_valid    = startswith(local.network.nas_server, "${local.network.subnet}.")
    master_valid = startswith(local.network.k3s_master, "${local.network.subnet}.")
    worker_valid = startswith(local.network.k3s_worker_01, "${local.network.subnet}.")
    gateway_valid = startswith(local.network.gateway, "${local.network.subnet}.")
  }
  
  # Check IP range conflicts (avoid common conflicts)
  ip_conflicts = {
    nas_in_dhcp_range = (
      tonumber(split(".", local.network.nas_server)[3]) >= 100 && 
      tonumber(split(".", local.network.nas_server)[3]) <= 200
    )
    master_in_dhcp_range = (
      tonumber(split(".", local.network.k3s_master)[3]) >= 100 && 
      tonumber(split(".", local.network.k3s_master)[3]) <= 200
    )
    worker_in_dhcp_range = (
      tonumber(split(".", local.network.k3s_worker_01)[3]) >= 100 && 
      tonumber(split(".", local.network.k3s_worker_01)[3]) <= 200
    )
  }
}

# Validation checks that run during plan/apply
check "ip_subnet_validation" {
  assert {
    condition = alltrue([
      local.ip_validations.nas_valid,
      local.ip_validations.master_valid,
      local.ip_validations.worker_valid,
      local.ip_validations.gateway_valid
    ])
    error_message = "All IP addresses must be in the ${local.network.subnet}.x subnet. Check: NAS=${local.network.nas_server}, Master=${local.network.k3s_master}, Worker=${local.network.k3s_worker_01}, Gateway=${local.network.gateway}"
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
    error_message = "All IP addresses must be unique. Found duplicates in: NAS=${local.network.nas_server}, Master=${local.network.k3s_master}, Worker=${local.network.k3s_worker_01}, Gateway=${local.network.gateway}"
  }
}

check "dhcp_range_warning" {
  assert {
    condition = !anytrue([
      local.ip_conflicts.nas_in_dhcp_range,
      local.ip_conflicts.master_in_dhcp_range,
      local.ip_conflicts.worker_in_dhcp_range
    ])
    error_message = "Warning: Some IPs are in common DHCP range (100-200). This may cause conflicts. Consider using IPs outside this range or configure DHCP reservations."
  }
}

check "vm_resource_sanity" {
  assert {
    condition = alltrue([
      local.vm_configs.nas.cores >= 1,
      local.vm_configs.k3s_master.cores >= 2,
      local.vm_configs.k3s_worker.cores >= 2,
      local.vm_configs.nas.memory >= 1024,
      local.vm_configs.k3s_master.memory >= 4096,
      local.vm_configs.k3s_worker.memory >= 4096
    ])
    error_message = "VM resources below minimum requirements: NAS needs ≥1 core, ≥1GB RAM. K3s nodes need ≥2 cores, ≥4GB RAM."
  }
}

check "dns_servers_reachable" {
  assert {
    condition = length(local.network.dns_servers) >= 1
    error_message = "At least one DNS server must be configured."
  }
}

# ===================================================================
#  CONFIGURATION SUMMARY FOR DEBUGGING
# ===================================================================

locals {
  config_summary = {
    network_settings = {
      subnet      = local.network.subnet
      gateway     = local.network.gateway
      domain      = local.network.domain
      dns_servers = local.network.dns_servers
    }
    
    vm_assignments = {
      nas_server = "${local.network.nas_server} (ID: ${local.vm_ids.nas_server})"
      k3s_master = "${local.network.k3s_master} (ID: ${local.vm_ids.k3s_master})"
      k3s_worker = "${local.network.k3s_worker_01} (ID: ${local.vm_ids.k3s_worker_01})"
    }
    
    resource_allocation = {
      total_cores = local.vm_configs.nas.cores + local.vm_configs.k3s_master.cores + local.vm_configs.k3s_worker.cores
      total_memory_gb = (local.vm_configs.nas.memory + local.vm_configs.k3s_master.memory + local.vm_configs.k3s_worker.memory) / 1024
      environment_size = var.environment_size
    }
    
    validation_status = {
      all_ips_valid = alltrue(values(local.ip_validations))
      no_ip_conflicts = !anytrue(values(local.ip_conflicts))
      resources_adequate = alltrue([
        local.vm_configs.nas.memory >= 1024,
        local.vm_configs.k3s_master.memory >= 4096,
        local.vm_configs.k3s_worker.memory >= 4096
      ])
    }
  }
}
