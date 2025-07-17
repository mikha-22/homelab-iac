# ===================================================================
#  SHARED OUTPUTS - CLEAN AND ACTIONABLE
# ===================================================================

# --- NETWORK CONFIGURATION ---
output "network" {
  description = "Core network settings"
  value = local.network
}

output "domain" {
  description = "Primary domain name"
  value = local.network.domain
}

output "dns_servers" {
  description = "DNS servers for VM configuration"
  value = local.network.dns_servers
}

output "gateway" {
  description = "Network gateway"
  value = local.network.gateway
}

# --- VM CONFIGURATION ---
output "vm_ids" {
  description = "VM ID assignments"
  value = local.enhanced_vm_ids
}

output "vm_configs" {
  description = "VM resource configurations"
  value = local.enhanced_vm_configs
}

output "full_ips" {
  description = "IP addresses with CIDR"
  value = local.full_ips
}

output "ssh_commands" {
  description = "SSH connection commands"
  value = local.ssh_commands
}

# --- GCP CONFIGURATION ---
output "gcp_project_id" {
  description = "GCP Project ID"
  value = local.gcp.project_id
}

output "gcp_region" {
  description = "GCP Region"
  value = local.gcp.region
}

# --- AUTHENTICATION SECRETS ---
output "proxmox_api_token" {
  description = "Proxmox API token"
  value = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
  sensitive = true
}

output "proxmox_ssh_private_key" {
  description = "Proxmox SSH private key"
  value = trimspace(data.google_secret_manager_secret_version.pm_ssh_private_key.secret_data)
  sensitive = true
}

output "nas_ssh_public_key" {
  description = "SSH public key for NAS VM"
  value = trimspace(data.google_secret_manager_secret_version.nas_ssh_key.secret_data)
  sensitive = true
}

output "cloudflare_api_token" {
  description = "Cloudflare API token"
  value = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
  sensitive = true
}

output "cloudflare_config" {
  description = "Cloudflare configuration"
  value = {
    account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
    zone_name  = local.network.domain
  }
  sensitive = true
}

output "k3s_cluster_token" {
  description = "K3s cluster token"
  value = trimspace(data.google_secret_manager_secret_version.k3s_cluster_token.secret_data)
  sensitive = true
}

output "argocd_admin_password" {
  description = "ArgoCD admin password"
  value = trimspace(data.google_secret_manager_secret_version.argocd_admin_password.secret_data)
  sensitive = true
}

output "eso_service_account_key" {
  description = "External Secrets Operator service account key"
  value = trimspace(data.google_secret_manager_secret_version.eso_service_account_key.secret_data)
  sensitive = true
}

# NOTE: tunnel_cname is handled directly in ArgoCD module since it's created by Cloudflare module

# --- TAGGING ---
output "common_tags" {
  description = "Common resource tags"
  value = local.common_tags
}

output "role_tags" {
  description = "Role-specific tags"
  value = local.role_tags
}

# --- INFRASTRUCTURE CONFIG ---
output "proxmox_config" {
  description = "Proxmox cluster configuration"
  value = local.proxmox
}

output "storage_config" {
  description = "Storage configuration"
  value = local.storage_config
}
