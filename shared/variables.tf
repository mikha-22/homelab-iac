# ===================================================================
#  SHARED VARIABLES WITH ESSENTIAL VALIDATION ONLY
#  Removed pedantic checks, kept operational safety nets
# ===================================================================

# --- GCP PROJECT CONFIGURATION ---
variable "gcp_project_id" {
  description = "GCP Project ID for secret management"
  type        = string
  default     = "homelab-secret-manager"
  
  validation {
    condition     = length(var.gcp_project_id) >= 6 && length(var.gcp_project_id) <= 30
    error_message = "GCP Project ID must be 6-30 characters."
  }
}

variable "gcp_region" {
  description = "GCP Region for resources"
  type        = string
  default     = "asia-southeast1"
}

# --- NETWORK CONFIGURATION ---
variable "network_override" {
  description = "Override default network settings (optional)"
  type = object({
    subnet      = optional(string, "192.168.1")
    gateway     = optional(string, "192.168.1.1")
    domain      = optional(string, "milenika.dev")
    dns_servers = optional(list(string), ["1.1.1.1", "8.8.8.8"])
  })
  default = {}
  
  validation {
    condition     = var.network_override.dns_servers != null ? length(var.network_override.dns_servers) <= 4 : true
    error_message = "Maximum of 4 DNS servers allowed."
  }
}

# --- VM ID VALIDATION ---
variable "vm_id_overrides" {
  description = "Override default VM IDs (optional, for advanced users)"
  type = object({
    base_template   = optional(number, 9999)
    master_template = optional(number, 9000)
    worker_template = optional(number, 9010)
    nas_server      = optional(number, 225)
    k3s_master      = optional(number, 181)
    k3s_worker_01   = optional(number, 182)
  })
  default = {}
  
  validation {
    condition = alltrue([
      for id in values(var.vm_id_overrides) : 
      id >= 100 && id <= 9999 if id != null
    ])
    error_message = "VM IDs must be between 100 and 9999."
  }
  
  validation {
    condition = length(compact(values(var.vm_id_overrides))) == length(toset(compact(values(var.vm_id_overrides))))
    error_message = "VM IDs must be unique."
  }
}

# --- ENVIRONMENT SIZING ---
variable "environment_size" {
  description = "Environment size preset (affects VM resources)"
  type        = string
  default     = "homelab"
  
  validation {
    condition     = contains(["minimal", "homelab", "development", "testing"], var.environment_size)
    error_message = "Environment size must be one of: minimal, homelab, development, testing."
  }
}

# --- RESOURCE OVERRIDES ---
variable "custom_vm_configs" {
  description = "Custom VM resource configurations (overrides environment_size presets)"
  type = object({
    nas = optional(object({
      cores  = optional(number, null)
      memory = optional(number, null)
      disk   = optional(number, null)
    }), {})
    k3s_master = optional(object({
      cores  = optional(number, null)
      memory = optional(number, null)
      disk   = optional(number, null)
    }), {})
    k3s_worker = optional(object({
      cores  = optional(number, null)
      memory = optional(number, null)
      disk   = optional(number, null)
    }), {})
  })
  default = {}
  
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "cores" || (value >= 1 && value <= 32) if value != null
      ])
    ])
    error_message = "CPU cores must be between 1 and 32."
  }
  
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "memory" || (value >= 512 && value <= 65536) if value != null
      ])
    ])
    error_message = "Memory must be between 512 MB and 64 GB."
  }
}

# --- K3S CONFIGURATION ---
variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.29.5+k3s1"
  
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "K3s version must be in format 'v1.29.5+k3s1'."
  }
}

# --- SIMPLE CONFIGURATION ---
variable "ssh_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "proxmox_nodes" {
  description = "List of Proxmox nodes in the cluster"
  type        = list(string)
  default     = ["pve1", "pve2"]
  
  validation {
    condition     = length(var.proxmox_nodes) >= 1 && length(var.proxmox_nodes) <= 10
    error_message = "Must have between 1 and 10 Proxmox nodes."
  }
}

# --- FEATURE FLAGS ---
variable "enable_monitoring" {
  description = "Enable monitoring stack (Prometheus, Grafana)"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup configurations"
  type        = bool
  default     = false
}

variable "enable_ha" {
  description = "Enable high availability features"
  type        = bool
  default     = false
}

# ===================================================================
#  COMPUTED VALUES AND PRESETS
# ===================================================================

locals {
  # Final network configuration
  final_network = {
    subnet      = var.network_override.subnet != null ? var.network_override.subnet : "192.168.1"
    gateway     = var.network_override.gateway != null ? var.network_override.gateway : "192.168.1.1"
    domain      = var.network_override.domain != null ? var.network_override.domain : "milenika.dev"
    dns_servers = var.network_override.dns_servers != null ? var.network_override.dns_servers : ["1.1.1.1", "8.8.8.8"]
  }
  
  # Environment presets
  environment_presets = {
    minimal = {
      nas        = { cores = 1, memory = 1024, disk = 20 }
      k3s_master = { cores = 2, memory = 4096, disk = 20 }
      k3s_worker = { cores = 2, memory = 4096, disk = 20 }
    }
    homelab = {
      nas        = { cores = 1, memory = 2048, disk = 50 }
      k3s_master = { cores = 6, memory = 8192, disk = 20 }
      k3s_worker = { cores = 6, memory = 8192, disk = 20 }
    }
    development = {
      nas        = { cores = 2, memory = 4096, disk = 100 }
      k3s_master = { cores = 8, memory = 16384, disk = 40 }
      k3s_worker = { cores = 8, memory = 16384, disk = 40 }
    }
    testing = {
      nas        = { cores = 4, memory = 8192, disk = 200 }
      k3s_master = { cores = 12, memory = 32768, disk = 80 }
      k3s_worker = { cores = 12, memory = 32768, disk = 80 }
    }
  }
  
  # Apply custom overrides to presets
  base_configs = local.environment_presets[var.environment_size]
  
  final_vm_configs = {
    nas = {
      cores  = var.custom_vm_configs.nas.cores != null ? var.custom_vm_configs.nas.cores : local.base_configs.nas.cores
      memory = var.custom_vm_configs.nas.memory != null ? var.custom_vm_configs.nas.memory : local.base_configs.nas.memory
      disk   = var.custom_vm_configs.nas.disk != null ? var.custom_vm_configs.nas.disk : local.base_configs.nas.disk
    }
    k3s_master = {
      cores  = var.custom_vm_configs.k3s_master.cores != null ? var.custom_vm_configs.k3s_master.cores : local.base_configs.k3s_master.cores
      memory = var.custom_vm_configs.k3s_master.memory != null ? var.custom_vm_configs.k3s_master.memory : local.base_configs.k3s_master.memory
      disk   = var.custom_vm_configs.k3s_master.disk != null ? var.custom_vm_configs.k3s_master.disk : local.base_configs.k3s_master.disk
    }
    k3s_worker = {
      cores  = var.custom_vm_configs.k3s_worker.cores != null ? var.custom_vm_configs.k3s_worker.cores : local.base_configs.k3s_worker.cores
      memory = var.custom_vm_configs.k3s_worker.memory != null ? var.custom_vm_configs.k3s_worker.memory : local.base_configs.k3s_worker.memory
      disk   = var.custom_vm_configs.k3s_worker.disk != null ? var.custom_vm_configs.k3s_worker.disk : local.base_configs.k3s_worker.disk
    }
  }
}

# ===================================================================
#  ESSENTIAL RUNTIME VALIDATION ONLY
# ===================================================================

check "ip_subnet_consistency" {
  assert {
    condition = startswith(local.final_network.gateway, "${local.final_network.subnet}.")
    error_message = "Gateway IP must be in the same subnet as base subnet."
  }
}

check "k3s_minimum_resources" {
  assert {
    condition = alltrue([
      local.final_vm_configs.k3s_master.memory >= 4096,
      local.final_vm_configs.k3s_worker.memory >= 4096
    ])
    error_message = "K3s nodes require at least 4GB RAM for stable operation."
  }
}
