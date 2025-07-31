# Load shared module for centralized secret management
module "shared" {
  source = "../../shared"
}

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = module.shared.proxmox_api_token
  
  ssh {
    username    = "root"
    private_key = module.shared.proxmox_ssh_private_key
  }
}

provider "null" {}

provider "local" {}
