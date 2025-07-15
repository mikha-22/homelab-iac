# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = var.gcp_project_id
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}
