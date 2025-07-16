output "deployment_status" {
  description = "GCS bucket deployment status and verification"
  value = {
    status = "✅ GCS bucket deployed successfully"
    
    resources = {
      bucket = {
        name     = google_storage_bucket.terraform_state.name
        location = google_storage_bucket.terraform_state.location
        url      = "gs://${google_storage_bucket.terraform_state.name}"
      }
      
      apis = {
        storage_api = google_project_service.storage.service
      }
    }
    
    verification = {
      bucket_created    = "✅ Terraform state bucket created"
      versioning       = "✅ Versioning enabled for state history"
      access_control   = "✅ Uniform bucket-level access enabled"
      lifecycle_policy = "✅ Prevent destroy protection enabled"
    }
    
    next_steps = [
      {
        action      = "Configure backend in modules"
        description = "Update terraform.tf files to use this bucket for state storage"
        command     = "# Add to terraform.tf:\n# backend \"gcs\" {\n#   bucket = \"${google_storage_bucket.terraform_state.name}\"\n#   prefix = \"module_name\"\n# }"
      },
      {
        action      = "Deploy secret manager"
        command     = "cd ../02_google_secret_manager && terraform apply"
        description = "Set up secret management for infrastructure credentials"
      }
    ]
    
    troubleshooting = {
      check_bucket     = "gsutil ls gs://${google_storage_bucket.terraform_state.name}"
      check_versioning = "gsutil versioning get gs://${google_storage_bucket.terraform_state.name}"
      list_objects     = "gsutil ls -la gs://${google_storage_bucket.terraform_state.name}/**"
    }
  }
}

# Legacy compatibility
output "bucket_name" {
  description = "The name of the GCS bucket created for Terraform state"
  value       = google_storage_bucket.terraform_state.name
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    bucket_name    = google_storage_bucket.terraform_state.name
    bucket_url     = "gs://${google_storage_bucket.terraform_state.name}"
    next_module    = "cd ../02_google_secret_manager && terraform apply"
    backend_config = "bucket = \"${google_storage_bucket.terraform_state.name}\""
  }
}
