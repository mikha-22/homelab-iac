output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "project_number" {
  description = "GCP Project Number"
  value       = data.google_project.current.number
}

output "service_account_email" {
  description = "External Secrets Operator service account email"
  value       = google_service_account.external_secrets.email
}

output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service account"
  value       = "iam.gke.io/gcp-service-account=${google_service_account.external_secrets.email}"
}

output "secrets_created" {
  description = "List of secrets created in Secret Manager"
  value       = keys(google_secret_manager_secret.homelab_secrets)
}

output "cluster_secret_store_config" {
  description = "Configuration for ClusterSecretStore"
  value = {
    project_id           = var.project_id
    service_account_name = "external-secrets"
    namespace           = var.k8s_namespace
  }
}
