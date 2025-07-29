# Data sources for authentication
data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}

provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "cloudflare" {
  api_token = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

provider "random" {}
