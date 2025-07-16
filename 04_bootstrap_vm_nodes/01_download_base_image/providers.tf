# ===================================================================
#  BASE IMAGE DOWNLOAD PROVIDERS
# ===================================================================

# Data sources for authentication
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

data "google_secret_manager_secret_version" "pm_ssh_private_key" {
  secret = "proxmox-ssh-private-key"
}

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
  
  ssh {
    username    = "root"
    private_key = trimspace(data.google_secret_manager_secret_version.pm_ssh_private_key.secret_data)
  }
}
