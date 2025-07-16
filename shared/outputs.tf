# ===================================================================
#  ENHANCED SHARED OUTPUTS WITH CENTRALIZED CONFIGURATION
# ===================================================================

# --- EXISTING OUTPUTS (ENHANCED) ---
output "network" {
  description = "Core network settings"
  value = local.network
}

output "vm_ids" {
  description = "Standardized VM ID assignments"
  value = local.enhanced_vm_ids
}

output "vm_configs" {
  description = "Enhanced VM resource configurations"
  value = local.enhanced_vm_configs
}

# --- NEW INFRASTRUCTURE CONFIGURATION OUTPUTS ---
output "proxmox_config" {
  description = "Complete Proxmox cluster configuration"
  value = local.proxmox
}

output "storage_config" {
  description = "Storage configuration for all modules"
  value = local.storage_config
}

output "kubernetes_cluster_config" {
  description = "Kubernetes cluster configuration"
  value = local.kubernetes
}

output "application_configs" {
  description = "Application deployment configurations"
  value = local.app_configs
}

output "operational_settings" {
  description = "Timeouts, retries, and operational parameters"
  value = {
    timeouts  = local.timeouts
    retries   = local.retries
    intervals = local.intervals
  }
}

output "naming_conventions" {
  description = "Standardized naming conventions"
  value = local.naming
}

output "file_locations" {
  description = "Template and configuration file locations"
  value = local.file_locations
}

# --- CONVENIENCE COMPUTED OUTPUTS ---
output "primary_proxmox_node" {
  description = "Primary Proxmox node"
  value = local.proxmox.nodes.primary
}

output "template_ids" {
  description = "All template VM IDs"
  value = local.proxmox.template_ids
}

output "k3s_node_configs" {
  description = "K3s node configurations for automation"
  value = local.kubernetes.nodes
}

output "helm_chart_versions" {
  description = "Helm chart versions for all applications"
  value = {
    argocd           = local.applications.argocd.chart_version
    external_secrets = local.applications.external_secrets.chart_version
    external_dns     = local.applications.external_dns.chart_version
  }
}

# --- EXISTING OUTPUTS (UNCHANGED) ---
output "full_ips" {
  description = "Complete IP addresses with CIDR"
  value = local.full_ips
}

output "ssh_commands" {
  description = "Ready-to-use SSH connection strings"
  value = local.ssh_commands
}

output "gcp_project_id" {
  description = "GCP Project ID for secret management"
  value = local.gcp.project_id
}

output "gcp_region" {
  description = "GCP Region"
  value = local.gcp.region
}

output "common_tags" {
  description = "Tags applied to all resources"
  value = local.common_tags
}

output "role_tags" {
  description = "Role-specific tags"
  value = local.role_tags
}

output "services" {
  description = "Service hostnames for ingress/DNS"
  value = local.services
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

output "ansible_inventory" {
  description = "Ready-to-use data for Ansible inventory"
  value = {
    k3s_master = {
      ip       = local.network.k3s_master
      hostname = local.kubernetes.nodes.master.hostname
      role     = local.kubernetes.nodes.master.role
    }
    k3s_workers = [
      {
        ip       = local.network.k3s_worker_01
        hostname = local.kubernetes.nodes.worker_01.hostname
        role     = local.kubernetes.nodes.worker_01.role
      }
    ]
  }
}

output "nas_ssh_public_key" {
  description = "SSH public key for NAS VM"
  value = trimspace(data.google_secret_manager_secret_version.nas_ssh_key.secret_data)
  sensitive = true
}

output "cloudflare_api_token" {
  description = "Cloudflare API token for external modules"
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

# NEW: K3s cluster token output
output "k3s_cluster_token" {
  description = "K3s cluster token for Ansible"
  value       = trimspace(data.google_secret_manager_secret_version.k3s_cluster_token.secret_data)
  sensitive   = true
}

# --- ENHANCED QUICK REFERENCE ---
output "quick_reference" {
  description = "All important info in one place"
  value = {
    # Network info
    network_info = {
      subnet  = local.network.subnet
      domain  = local.network.domain
      gateway = local.network.gateway
    }
    
    # Infrastructure
    infrastructure = {
      nas_ip     = local.network.nas_server
      master_ip  = local.network.k3s_master
      worker_ips = [local.network.k3s_worker_01]
    }
    
    # Proxmox
    proxmox = {
      primary_node = local.proxmox.nodes.primary
      endpoints    = local.proxmox.endpoints
      templates    = local.proxmox.template_ids
      storage      = local.proxmox.storage
    }
    
    # Applications
    applications = {
      argocd_namespace = local.applications.argocd.namespace
      eso_namespace    = local.applications.external_secrets.namespace
      tunnel_name      = local.applications.cloudflare_tunnel.name
    }
    
    # Operational
    timeouts = local.timeouts
    
    # Quick commands
    ssh_commands = local.ssh_commands
    
    next_steps = [
      "SSH to NAS: ${local.ssh_commands.nas_server}",
      "SSH to K3s Master: ${local.ssh_commands.k3s_master}",
      "Test NFS: showmount -e ${local.network.nas_server}",
      "Check K3s: kubectl get nodes"
    ]
  }
}
