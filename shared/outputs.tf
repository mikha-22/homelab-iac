# Network Configuration
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

# VM Configuration
output "vm_configs" {
  value = local.vm_configs
}

output "vm_ids" {
  value = local.vm_ids
}

# Tags
output "common_tags" {
  value = local.common_tags
}

output "role_tags" {
  value = local.role_tags
}

# SSH Commands
output "ssh_commands" {
  value = local.ssh_commands
}

# Secrets (Sensitive)
output "proxmox_api_token" {
  description = "Proxmox API token for provider authentication"
  value       = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
  sensitive   = true
}

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
