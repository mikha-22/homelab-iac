# ===================================================================
#  SHARED MODULE: DATA SOURCES
# ===================================================================

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
