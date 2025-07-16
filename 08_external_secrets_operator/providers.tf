# ===================================================================
#  EXTERNAL SECRETS OPERATOR - PROVIDERS - SIMPLIFIED
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

# NOTE: Removed duplicate data source - now comes from shared module
# Access service account key via module.shared.eso_service_account_key
