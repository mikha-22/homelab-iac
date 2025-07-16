# ===================================================================
#  CLOUDFLARE TUNNEL PROVIDERS
# ===================================================================

# Data sources for authentication
data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}

data "google_secret_manager_secret_version" "cloudflare_account_id" {
  secret = "cloudflare-account-id"
}

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "cloudflare" {
  alias     = "dns_tunnels"
  api_token = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
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

provider "random" {
  alias = "generation"
}
