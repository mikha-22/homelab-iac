output "secrets" {
  description = "Created secrets"
  value = {
    count        = length(keys(google_secret_manager_secret.homelab_secrets))
    secret_names = keys(google_secret_manager_secret.homelab_secrets)
  }
}

output "service_account" {
  description = "External Secrets Operator service account"
  value = {
    email        = google_service_account.external_secrets.email
    display_name = google_service_account.external_secrets.display_name
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_images    = "cd ../03_nas/01_base_images && terraform apply"
    verify_secrets   = "gcloud secrets list --project=${var.project_id}"
    test_access      = "gcloud secrets versions access latest --secret=proxmox-api-token --project=${var.project_id}"
  }
}
