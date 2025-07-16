# ===================================================================
#  SHARED DATA SOURCES FOR AUTHENTICATION
#  No provider blocks - each module configures its own providers
# ===================================================================

# --- DATA SOURCES FOR AUTHENTICATION ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_password" {
  secret = "proxmox-ssh-password"
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

# NOTE: No provider blocks here. Each module that uses the shared module
# will configure its own Google provider, and these data sources will
# automatically use that provider configuration.
