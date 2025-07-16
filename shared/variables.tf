# ===================================================================
#  SHARED VARIABLES WITH COMPREHENSIVE VALIDATION
#  FIXED: Added validation for all inputs to prevent runtime failures
# ===================================================================

# --- GCP PROJECT CONFIGURATION ---
variable "gcp_project_id" {
  description = "GCP Project ID for secret management"
  type        = string
  default     = "homelab-secret-manager"
  
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.gcp_project_id))
    error_message = "GCP Project ID must be 6-30 characters, start with lowercase letter, contain only lowercase letters, numbers, and hyphens."
  }
  
  validation {
    condition     = !can(regex("--", var.gcp_project_id))
    error_message = "GCP Project ID cannot contain consecutive hyphens."
  }
}

variable "gcp_region" {
  description = "GCP Region for resources"
  type        = string
  default     = "asia-southeast1"
  
  validation {
    condition = contains([
      "asia-east1", "asia-east2", "asia-northeast1", "asia-northeast2", "asia-northeast3",
      "asia-south1", "asia-south2", "asia-southeast1", "asia-southeast2",
      "australia-southeast1", "australia-southeast2",
      "europe-central2", "europe-north1", "europe-southwest1", "europe-west1",
      "europe-west2", "europe-west3", "europe-west4", "europe-west6", "europe-west8", "europe-west9",
      "northamerica-northeast1", "northamerica-northeast2",
      "southamerica-east1", "southamerica-west1",
      "us-central1", "us-east1", "us-east4", "us-east5", "us-south1", 
      "us-west1", "us-west2", "us-west3", "us-west4"
    ], var.gcp_region)
    error_message = "GCP Region must be a valid Google Cloud region."
  }
}

# --- NETWORK CONFIGURATION WITH VALIDATION ---
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
    condition = var.network_override.subnet != null ? can(regex("^((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){3}$", var.network_override.subnet)) : true
    error_message = "Subnet must be in format 'x.x.x' where x is 0-255 (e.g., '192.168.1')."
  }
  
  validation {
    condition = var.network_override.gateway != null ? can(cidrhost("${var.network_override.gateway}/24", 0)) : true
    error_message = "Gateway must be a valid IPv4 address."
  }
  
  validation {
    condition = var.network_override.domain != null ? can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.network_override.domain)) : true
    error_message = "Domain must be valid format (e.g., 'example.com', 'sub.example.com')."
  }
  
  validation {
    condition = var.network_override.dns_servers != null ? alltrue([
      for ip in var.network_override.dns_servers : can(cidrhost("${ip}/32", 0))
    ]) : true
    error_message = "All DNS servers must be valid IPv4 addresses."
  }
  
  validation {
    condition = var.network_override.dns_servers != null ? length(var.network_override.dns_servers) <= 4 : true
    error_message = "Maximum of 4 DNS servers allowed."
  }
}

# --- VM ID VALIDATION WITH CONFLICT CHECKING ---
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
    error_message = "All VM IDs must be between 100 and 9999."
  }
  
  # Check for duplicates
  validation {
    condition = length(compact(values(var.vm_id_overrides))) == length(toset(compact(values(var.vm_id_overrides))))
    error_message = "VM IDs must be unique - no duplicates allowed."
  }
  
  # Validate Proxmox reserved ranges
  validation {
    condition = alltrue([
      for id in values(var.vm_id_overrides) :
      !(id >= 1 && id <= 99) if id != null  # Proxmox reserved range
    ])
    error_message = "VM IDs 1-99 are reserved by Proxmox. Use IDs >= 100."
  }
  
  # Check for common conflicts
  validation {
    condition = alltrue([
      for id in values(var.vm_id_overrides) :
      !(id >= 200 && id <= 299) || id == var.vm_id_overrides.nas_server if id != null
    ])
    error_message = "VM IDs 200-299 are reserved for infrastructure VMs. Only NAS server (225) is allowed."
  }
}

# --- RESOURCE SIZING WITH VALIDATION ---
variable "environment_size" {
  description = "Environment size preset (affects VM resources)"
  type        = string
  default     = "homelab"
  
  validation {
    condition     = contains(["minimal", "homelab", "development", "testing"], var.environment_size)
    error_message = "Environment size must be one of: minimal, homelab, development, testing."
  }
}

# --- SSH KEY CONFIGURATION WITH VALIDATION ---
variable "ssh_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  
  validation {
    condition     = can(regex("\\.(pub|pem)$", var.ssh_key_path))
    error_message = "SSH key path should end with .pub (public key) or .pem (private key)."
  }
  
  validation {
    condition     = !can(regex("id_rsa$", var.ssh_key_path))
    error_message = "SSH key path should point to public key (.pub), not private key."
  }
}

# --- PROXMOX CONFIGURATION WITH VALIDATION ---
variable "proxmox_nodes" {
  description = "List of Proxmox nodes in the cluster"
  type        = list(string)
  default     = ["pve1", "pve2"]
  
  validation {
    condition     = length(var.proxmox_nodes) >= 1 && length(var.proxmox_nodes) <= 10
    error_message = "Must have between 1 and 10 Proxmox nodes."
  }
  
  validation {
    condition = alltrue([
      for node in var.proxmox_nodes : 
      can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", node)) && length(node) >= 3 && length(node) <= 15
    ])
    error_message = "Proxmox node names must be 3-15 characters, start with lowercase letter, end with letter/number, contain only lowercase letters, numbers, and hyphens."
  }
  
  validation {
    condition = length(var.proxmox_nodes) == length(toset(var.proxmox_nodes))
    error_message = "Proxmox node names must be unique."
  }
}

# --- KUBERNETES CONFIGURATION WITH VALIDATION ---
variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.29.5+k3s1"
  
  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+k3s[0-9]+$", var.k3s_version))
    error_message = "K3s version must be in format 'v1.29.5+k3s1'."
  }
  
  validation {
    condition = tonumber(split(".", substr(var.k3s_version, 1, -1))[0]) >= 1 && tonumber(split(".", substr(var.k3s_version, 1, -1))[1]) >= 24
    error_message = "K3s version must be 1.24 or higher."
  }
}

# --- RESOURCE LIMITS WITH VALIDATION ---
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
  
  # Validate CPU cores
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "cores" || (value >= 1 && value <= 32) if value != null
      ])
    ])
    error_message = "CPU cores must be between 1 and 32."
  }
  
  # Validate memory (in MB)
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "memory" || (value >= 512 && value <= 65536) if value != null
      ])
    ])
    error_message = "Memory must be between 512 MB and 64 GB (65536 MB)."
  }
  
  # Validate disk size (in GB)
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "disk" || (value >= 10 && value <= 1000) if value != null
      ])
    ])
    error_message = "Disk size must be between 10 GB and 1000 GB."
  }
  
  # Validate memory alignment (must be multiple of 256 MB for efficiency)
  validation {
    condition = alltrue([
      for vm_type, config in var.custom_vm_configs : alltrue([
        for key, value in config : 
        key != "memory" || (value % 256 == 0) if value != null
      ])
    ])
    error_message = "Memory must be a multiple of 256 MB for optimal performance."
  }
}

# --- FEATURE FLAGS WITH VALIDATION ---
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

# --- NETWORK VALIDATION LOCALS ---
locals {
  # Merge user overrides with defaults
  final_network = {
    subnet      = var.network_override.subnet != null ? var.network_override.subnet : "192.168.1"
    gateway     = var.network_override.gateway != null ? var.network_override.gateway : "192.168.1.1"
    domain      = var.network_override.domain != null ? var.network_override.domain : "milenika.dev"
    dns_servers = var.network_override.dns_servers != null ? var.network_override.dns_servers : ["1.1.1.1", "8.8.8.8"]
  }
  
  # Validate IP addresses are in same subnet
  subnet_base = local.final_network.subnet
  gateway_valid = startswith(local.final_network.gateway, "${local.subnet_base}.")
}

# --- RUNTIME VALIDATION CHECKS ---
check "network_consistency" {
  assert {
    condition     = local.gateway_valid
    error_message = "Gateway IP (${local.final_network.gateway}) must be in the same subnet as the base subnet (${local.subnet_base}.x)."
  }
}

check "vm_id_availability" {
  assert {
    condition = alltrue([
      for vm_type, id in var.vm_id_overrides :
      id == null || id >= 100
    ])
    error_message = "All VM IDs must be 100 or higher to avoid Proxmox system conflicts."
  }
}

# --- ENVIRONMENT SIZING PRESETS WITH VALIDATION ---
locals {
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

# --- RESOURCE VALIDATION CHECKS ---
check "resource_limits" {
  assert {
    condition = alltrue([
      local.final_vm_configs.nas.memory >= 1024,
      local.final_vm_configs.k3s_master.memory >= 4096,
      local.final_vm_configs.k3s_worker.memory >= 4096
    ])
    error_message = "NAS requires ≥1GB RAM, K3s master/worker require ≥4GB RAM for stable operation."
  }
}

check "cpu_allocation" {
  assert {
    condition = (
      local.final_vm_configs.nas.cores + 
      local.final_vm_configs.k3s_master.cores + 
      local.final_vm_configs.k3s_worker.cores
    ) <= 64
    error_message = "Total CPU allocation exceeds reasonable limits (64 cores). Reduce VM core counts."
  }
}

check "memory_allocation" {
  assert {
    condition = (
      local.final_vm_configs.nas.memory + 
      local.final_vm_configs.k3s_master.memory + 
      local.final_vm_configs.k3s_worker.memory
    ) <= 131072  # 128 GB
    error_message = "Total memory allocation exceeds reasonable limits (128 GB). Reduce VM memory."
  }
}
