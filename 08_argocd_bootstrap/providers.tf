# --- GOOGLE PROVIDER CONFIGURATION ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- KUBERNETES AND HELM PROVIDERS ---
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}
