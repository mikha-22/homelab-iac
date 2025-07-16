# ===================================================================
#  ARGOCD BOOTSTRAP PROVIDERS
# ===================================================================

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  alias   = "primary"
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "kubernetes" {
  alias       = "k3s_cluster"
  config_path = "~/.kube/config"
}

provider "helm" {
  alias = "k3s_apps"
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

# --- DATA SOURCES FOR AUTHENTICATION ---
data "google_secret_manager_secret_version" "argocd_admin_password" {
  provider = google.primary
  secret   = "argocd-admin-password"
}

data "google_secret_manager_secret_version" "tunnel_cname" {
  provider = google.primary
  secret   = "tunnel-cname"
}
