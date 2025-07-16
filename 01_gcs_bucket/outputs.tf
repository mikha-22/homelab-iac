output "bucket" {
  description = "GCS bucket information"
  value = {
    name     = google_storage_bucket.terraform_state.name
    location = google_storage_bucket.terraform_state.location
    url      = "gs://${google_storage_bucket.terraform_state.name}"
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_secrets = "cd ../02_google_secret_manager && terraform apply"
    check_bucket   = "gsutil ls gs://${google_storage_bucket.terraform_state.name}"
  }
}

output "backend_config" {
  description = "Backend configuration for other modules"
  value = {
    bucket = google_storage_bucket.terraform_state.name
    prefix = "module_name"
  }
}
