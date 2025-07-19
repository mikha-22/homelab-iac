# ===================================================================
#  HOMELAB SHARED CONFIGURATION - SINGLE FILE
#  Replaces: infrastructure-config.tf, network-config.tf, variables.tf
# ===================================================================
# --- VARIABLES ---
variable "network_subnet" {
  description = "Network subnet (e.g., 192.168.1)"
  type        = string
  default     = "192.168.1"
}

variable "domain" {
  description = "Your domain name"
  type        = string
  default     = "milenika.dev"
}

variable "nas_ip" {
  description = "NAS server IP (last octet)"
  type        = number
  default     = 225
}

variable "k3s_master_ip" {
  description = "K3s master IP (last octet)"
  type        = number
  default     = 181
}

variable "k3s_worker_ip" {
  description = "K3s worker IP (last octet)"
  type        = number
  default     = 182
}

variable "gateway_ip" {
  description = "Gateway IP (last octet)"
  type        = number
  default     = 1
}

variable "nas_cores" {
  description = "NAS VM CPU cores"
  type        = number
  default     = 1
}

variable "nas_memory" {
  description = "NAS VM memory (MB)"
  type        = number
  default     = 2048
}

variable "k3s_cores" {
  description = "K3s node CPU cores"
  type        = number
  default     = 6
}

variable "k3s_memory" {
  description = "K3s node memory (MB)"
  type        = number
  default     = 8192
}

variable "base_template_id" {
  description = "Base template VM ID"
  type        = number
  default     = 9999
}

variable "nas_vm_id" {
  description = "NAS VM ID"
  type        = number
  default     = 225
}

variable "k3s_master_vm_id" {
  description = "K3s master VM ID"
  type        = number
  default     = 181
}

variable "k3s_worker_vm_id" {
  description = "K3s worker VM ID"
  type        = number
  default     = 182
}

# --- SECRET DATA SOURCES ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_private_key" {
  secret = "proxmox-ssh-private-key"
}

data "google_secret_manager_secret_version" "nas_ssh_key" {
  secret = "nas-vm-ssh-key"
}

data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}

data "google_secret_manager_secret_version" "cloudflare_account_id" {
  secret = "cloudflare-account-id"
}

data "google_secret_manager_secret_version" "k3s_cluster_token" {
  secret = "k3s-cluster-token"
}

data "google_secret_manager_secret_version" "argocd_admin_password" {
  secret = "argocd-admin-password"
}

data "google_secret_manager_secret_version" "eso_service_account_key" {
  secret = "external-secrets-service-account-key"
}

# --- COMPUTED VALUES ---
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

# --- OUTPUTS ---
output "network" {
  value = local.network
}

output "full_ips" {
  value = local.full_ips
}

output "domain" {
  value = local.network.domain
}

output "dns_servers" {
  value = local.network.dns_servers
}

output "gateway" {
  value = local.network.gateway
}

output "vm_configs" {
  value = local.vm_configs
}

output "vm_ids" {
  value = local.vm_ids
}

output "common_tags" {
  value = local.common_tags
}

output "role_tags" {
  value = local.role_tags
}

output "ssh_commands" {
  value = local.ssh_commands
}

# Secrets
output "nas_ssh_public_key" {
  value     = trimspace(data.google_secret_manager_secret_version.nas_ssh_key.secret_data)
  sensitive = true
}

output "proxmox_ssh_private_key" {
  value     = trimspace(data.google_secret_manager_secret_version.pm_ssh_private_key.secret_data)
  sensitive = true
}

output "k3s_cluster_token" {
  value     = trimspace(data.google_secret_manager_secret_version.k3s_cluster_token.secret_data)
  sensitive = true
}

output "argocd_admin_password" {
  value     = trimspace(data.google_secret_manager_secret_version.argocd_admin_password.secret_data)
  sensitive = true
}

output "eso_service_account_key" {
  value     = trimspace(data.google_secret_manager_secret_version.eso_service_account_key.secret_data)
  sensitive = true
}

output "cloudflare_api_token" {
  value     = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
  sensitive = true
}

output "cloudflare_config" {
  value = {
    account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
    zone_name  = local.network.domain
  }
  sensitive = true
}

output "gcp_project_id" {
  value = "homelab-secret-manager"
}
