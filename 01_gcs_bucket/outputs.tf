# ===================================================================
#  GCS BUCKET OUTPUTS - ESSENTIAL ONLY
# ===================================================================

output "bucket" {
  description = "GCS bucket information"
  value = {
    name     = google_storage_bucket.terraform_state.name
    location = google_storage_bucket.terraform_state.location
  }
}
