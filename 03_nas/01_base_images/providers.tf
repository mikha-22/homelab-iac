# --- GOOGLE PROVIDER FOR FETCHING SECRETS ---
data "google_secret_manager_secret_version" "pm_api_token" {
  secret = "proxmox-api-token"
}

provider "google" {
  project = "homelab-secret-manager"
}

# --- PROXMOX PROVIDER CONFIGURATION ---
provider "proxmox" {
  endpoint  = "https://pve1.local:8006"
  insecure  = true
  api_token = trimspace(data.google_secret_manager_secret_version.pm_api_token.secret_data)
  # GSM data fetched on main.tf is used here, notice the syntax,
  # data.google_secret_manager_secret_version.pm_api_token.secret_data
  #                                           ^we created this, which contains the attributes of proxmox-api-token
  #                                           then we  want the value of the secret_data attribute
}
