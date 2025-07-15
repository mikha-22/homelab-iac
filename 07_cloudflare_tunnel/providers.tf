# --- GOOGLE PROVIDER CONFIGURATION ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- CLOUDFLARE PROVIDER CONFIGURATION ---
provider "cloudflare" {
  api_token = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
}

# --- KUBERNETES PROVIDER CONFIGURATION ---
provider "kubernetes" {
  config_path = "~/.kube/config"
}

# --- HELM PROVIDER CONFIGURATION ---
provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}
