# ===================================================================
#  STEP 1: Bootstrap GCS Bucket (run once)
#  File: 01_gcs_bucket/main.tf
# ===================================================================

# Create the GCS bucket for shared Terraform state
resource "google_storage_bucket" "terraform_state" {
  name          = "homelab-terraform-state-shared"
  location      = "asia-southeast1"
  force_destroy = false

  # Enable versioning for state file history
  versioning {
    enabled = true
  }

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  # Security settings
  uniform_bucket_level_access = true
}

# Enable required API
resource "google_project_service" "storage" {
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}
