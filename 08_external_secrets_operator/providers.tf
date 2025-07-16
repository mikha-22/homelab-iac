# ===================================================================
#  EXTERNAL SECRETS OPERATOR - PROVIDERS
# ===================================================================

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  alias   = "primary"
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "kubernetes" {
  alias       = "k3s_cluster"
  config_path = var.kubeconfig_path
}

provider "helm" {
  alias = "k3s_apps"
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "time" {
  alias = "scheduling"
}

provider "null" {}

# --- DATA SOURCES ---
data "google_secret_manager_secret_version" "service_account_key" {
  provider = google.primary
  secret   = var.service_account_secret_name
}
