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

# NOTE: tunnel-cname secret is handled directly in modules that need it
# since it's created by the Cloudflare tunnel module
