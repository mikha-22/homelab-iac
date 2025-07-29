# Load shared module for centralized secret management
module "shared" {
  source = "../../shared"
}

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- PROXMOX PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = module.shared.proxmox_api_token
}
