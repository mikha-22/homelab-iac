# ===================================================================
#  TEMPLATE DISTRIBUTION PROVIDERS - SIMPLIFIED
# ===================================================================

# --- PROVIDER CONFIGURATIONS ---
provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

provider "null" {}

# NOTE: Removed duplicate data sources - these now come from shared module
# All authentication data is accessed via module.shared.* outputs
