# ===================================================================
#  STEP 1: Bootstrap GCS Bucket (run once)
#  File: 01_gcs_bucket/main.tf
# ===================================================================

# Create the GCS bucket for shared Terraform state
resource "google_storage_bucket" "terraform_state" { # provisioning a resource, resource type is "google storage bucket",
                                                     # local name of this particular resource is "teraform_state"
  name          = "homelab-terraform-state-shared"   # configs, populating the values of keys, dependent on resource type
  location      = "asia-southeast1"
  force_destroy = false                              # disables the option to force destroy

  # Enable versioning for state file history
  versioning {                                       # some configs are a map, not a simple-key value, this one contains
                                                     # another subconfig (key-values), for a config (in this case a map)
    enabled = true
  }

  # Prevent accidental deletion
  lifecycle {                                        # prevents terraform destroy, making the bucket permanent basically
    prevent_destroy = true
  }

  # Security settings
  uniform_bucket_level_access = true                 # permissions for the whole bucket is the same, for folders,
}                                                    # subfolders, etc

# Enable required API
resource "google_project_service" "storage" {        # enable the API, doesn't matter if its written below or above the
  service            = "storage.googleapis.com"      # bucket provisioning, terraform doesnt read from top to bottom
  disable_on_destroy = false                         # it understands hierarchical structure instead, allowing implicit
  }                                                  # dependency. On this instance, for example terraform knows that 
                                                     # enabling the API should happen before talking to that API.
