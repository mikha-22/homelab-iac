# ===================================================================
#  GCS BUCKET OUTPUTS - ESSENTIAL ONLY
# ===================================================================

output "bucket" { # Declaring that we have an output object named bucket
  description = "GCS bucket information" # What is this object? information for the created Bucket
  value = { # What are the keys of this object/map? name and location
    name     = google_storage_bucket.terraform_state.name # the value is fetched from the google_storage_bucket.terraform_state.name
                                                          # this is provider dependent 
    location = google_storage_bucket.terraform_state.location
  }
}
