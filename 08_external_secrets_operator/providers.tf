# ===================================================================
#  EXTERNAL SECRETS OPERATOR PROVIDERS - SIMPLIFIED
# ===================================================================

provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

provider "time" {}

provider "null" {}
