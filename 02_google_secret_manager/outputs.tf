output "deployment_status" {
  description = "Secret Manager deployment status and verification"
  value = {
    status = "✅ Google Secret Manager deployed successfully"
    
    resources = {
      secrets = {
        count        = length(keys(google_secret_manager_secret.homelab_secrets))
        secret_names = keys(google_secret_manager_secret.homelab_secrets)
      }
      
      service_account = {
        email        = google_service_account.external_secrets.email
        display_name = google_service_account.external_secrets.display_name
        key_created  = google_service_account_key.external_secrets_key.name
      }
      
      apis = {
        secret_manager = google_project_service.secretmanager.service
        iam_api       = google_project_service.iam.service
      }
    }
    
    verification = {
      secrets_created     = "✅ ${length(keys(google_secret_manager_secret.homelab_secrets))} secrets created"
      service_account     = "✅ External Secrets Operator service account created"
      iam_permissions     = "✅ Secret Manager access permissions configured"
      auto_key_storage    = "✅ Service account key automatically stored in secrets"
    }
    
    next_steps = [
      {
        action      = "Deploy base images"
        command     = "cd ../03_nas/01_base_images && terraform apply"
        description = "Download Ubuntu cloud images to Proxmox"
      },
      {
        action      = "Verify secret access"
        command     = "gcloud secrets list --project=${var.project_id}"
        description = "Confirm all secrets are accessible"
      }
    ]
    
    troubleshooting = {
      list_secrets        = "gcloud secrets list --project=${var.project_id}"
      check_service_account = "gcloud iam service-accounts describe ${google_service_account.external_secrets.email}"
      test_secret_access  = "gcloud secrets versions access latest --secret=proxmox-api-token --project=${var.project_id}"
      check_permissions   = "gcloud projects get-iam-policy ${var.project_id}"
    }
  }
}

# Legacy compatibility
output "project_id" {
  description = "GCP Project ID"
  value = var.project_id
}

output "project_number" {
  description = "GCP Project Number"
  value = data.google_project.current.number
}

output "service_account_email" {
  description = "External Secrets Operator service account email"
  value = google_service_account.external_secrets.email
}

output "workload_identity_annotation" {
  description = "Annotation to add to Kubernetes service account"
  value = "iam.gke.io/gcp-service-account=${google_service_account.external_secrets.email}"
}

output "secrets_created" {
  description = "List of secrets created in Secret Manager"
  value = keys(google_secret_manager_secret.homelab_secrets)
}

output "cluster_secret_store_config" {
  description = "Configuration for ClusterSecretStore"
  value = {
    project_id           = var.project_id
    service_account_name = "external-secrets"
    namespace           = var.k8s_namespace
  }
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    project_id         = var.project_id
    service_account    = google_service_account.external_secrets.email
    secrets_count      = length(keys(google_secret_manager_secret.homelab_secrets))
    next_module        = "cd ../03_nas/01_base_images && terraform apply"
    verify_secrets     = "gcloud secrets list --project=${var.project_id}"
  }
}
