# ===================================================================
#  SHARED DATA SOURCES FOR AUTHENTICATION
#  Central location for all secret manager data sources
# ===================================================================

# --- PROXMOX AUTHENTICATION ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_private_key" {
  secret = "proxmox-ssh-private-key"
}

# --- SSH KEYS ---
data "google_secret_manager_secret_version" "nas_ssh_key" {
  secret = "nas-vm-ssh-key"
}

# --- CLOUDFLARE AUTHENTICATION ---
data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}

data "google_secret_manager_secret_version" "cloudflare_account_id" {
  secret = "cloudflare-account-id"
}

# --- KUBERNETES CLUSTER ---
data "google_secret_manager_secret_version" "k3s_cluster_token" {
  secret = "k3s-cluster-token"
}

# --- APPLICATION SECRETS ---
data "google_secret_manager_secret_version" "argocd_admin_password" {
  secret = "argocd-admin-password"
}

data "google_secret_manager_secret_version" "eso_service_account_key" {
  secret = "external-secrets-service-account-key"
}

data "google_secret_manager_secret_version" "tunnel_cname" {
  secret = "tunnel-cname"
}

# NOTE: No provider blocks here. Each module that uses the shared module
# will configure its own Google provider, and these data sources will
# automatically use that provider configuration.
