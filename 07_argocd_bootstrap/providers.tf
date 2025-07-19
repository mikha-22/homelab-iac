# ===================================================================
#  ARGOCD BOOTSTRAP PROVIDERS - SIMPLIFIED
# ===================================================================

provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
