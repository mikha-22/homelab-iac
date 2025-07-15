output "bucket_name" {
  description = "The name of the GCS bucket created for Terraform state."
  value       = google_storage_bucket.terraform_state.name
}

output "next_steps" {
  description = "Instructions for configuring the GCS backend in other modules."
  value = <<-EOT
    ✅ Bucket created: ${google_storage_bucket.terraform_state.name}
    
    Now update all your terraform.tf files with:
    
    backend "gcs" {
      bucket = "${google_storage_bucket.terraform_state.name}"
      prefix = "homelab" # Or a more specific prefix for each module
    }
  EOT
}
