# --- GOOGLE PROVIDER FOR FETCHING SECRETS ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- PROXMOX PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
}
