# Create the GCS bucket for shared Terraform state
resource "google_storage_bucket" "terraform_state" { 
  # Provisioning a resource, resource type is "google storage bucket",
  # L ocal name of this particular resource is "teraform_state"
  # Configs, populating the values of keys, dependent on resource type
  name          = "homelab-terraform-state-shared"
  location      = "asia-southeast1"
  # disables the option to force destroy
  force_destroy = false
  # Enable versioning for state file history
  # Some configs are a map, not a simple-key value, this one contains
  # subconfig (key-values), for a config (in this case a map)
  versioning {
    enabled = true
  }
  # Prevent accidental deletion
  # prevents terraform destroy, making the bucket permanent basically
  lifecycle {
    prevent_destroy = true
  }

  # Security settings
  # permissions for the whole bucket is the same, for folders, subfolders, etc
  uniform_bucket_level_access = true
}                                                    
# # Enable required API
# enable the API, doesn't matter if its written below or above the
resource "google_project_service" "storage" {
  # bucket provisioning, terraform doesnt read from top to bottom
  service            = "storage.googleapis.com"

  disable_on_destroy = false
  }                                                  
  # it understands hierarchical structure instead, allowing implicit
  # dependency. On this instance, for example terraform knows that 
  # enabling the API should happen before talking to that API.
