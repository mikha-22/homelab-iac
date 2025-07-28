# Declaring that we have an output object named bucket
output "bucket" { 
  # What is this object? information for the created Bucket
  description = "GCS bucket information" 
  # What are the keys of this object/map? name and location
  value = { 
    # The value is fetched from the google_storage_bucket.terraform_state.name
    name     = google_storage_bucket.terraform_state.name 
    # This is provider dependent                                                    
    location = google_storage_bucket.terraform_state.location
  }
}
