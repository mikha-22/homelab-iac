# ===================================================================
#  STEP 1: Bootstrap GCS Bucket (run once)
#  File: 00_bootstrap_backend/main.tf
# ===================================================================

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = "homelab-secret-manager"
  region  = "asia-southeast1"
}

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
  service = "storage.googleapis.com"
  disable_on_destroy = false
}

output "bucket_name" {
  value = google_storage_bucket.terraform_state.name
}

output "next_steps" {
  value = <<-EOT
    ✅ Bucket created: ${google_storage_bucket.terraform_state.name}
    
    Now update all your terraform.tf files with:
    
    backend "gcs" {
      bucket = "${google_storage_bucket.terraform_state.name}"
      prefix = "homelab"
    }
  EOT
}
