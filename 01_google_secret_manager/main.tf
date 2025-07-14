# ===================================================================
#  PROJECT: Google Secret Manager for Homelab
#  Creates Secret Manager secrets and service account for ESO integration
# ===================================================================

# --- PROVIDER ---
provider "google" {
  project = var.project_id
  region  = var.region
}

# --- DATA SOURCES ---
data "google_project" "current" {
  project_id = var.project_id
}

# --- LOCALS ---
# Merge the static secrets from the tfvars file with the dynamic SSH key secrets.
# This allows us to manage all secrets with a single, clean for_each loop.
locals {
  all_secrets = merge(
    var.secrets,
    
    # Conditionally add the user SSH key secret if a path is provided.
    var.ssh_public_key_path != "" ? {
      "nas-vm-ssh-key" = {
        secret_data = file(var.ssh_public_key_path)
        description = "Public SSH key for general VM user access, managed by Terraform."
      }
    } : {},

    # Conditionally add the Packer SSH key secret if a path is provided.
    var.packer_public_key_path != "" ? {
      "packer-vm-ssh-key-public" = {
        secret_data = file(var.packer_public_key_path)
        description = "Public SSH key for Packer automation to provision VM templates."
      }
    } : {}
  )
}

# --- ENABLE APIS ---
resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
  
  disable_dependent_services = true
  disable_on_destroy         = false
}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  
  disable_dependent_services = true
  disable_on_destroy         = false
}

# --- SECRET MANAGER SECRETS ---
resource "google_secret_manager_secret" "homelab_secrets" {
  # Use the merged local map instead of the variable directly.
  for_each = local.all_secrets

  secret_id = each.key
  
  labels = {
    environment = "homelab"
    managed_by  = "terraform"
    component   = "secrets"
  }

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "homelab_secret_versions" {
  # Use the merged local map here as well.
  for_each = local.all_secrets

  secret      = google_secret_manager_secret.homelab_secrets[each.key].name
  secret_data = each.value.secret_data
}

# --- SERVICE ACCOUNT FOR EXTERNAL SECRETS OPERATOR ---
resource "google_service_account" "external_secrets" {
  account_id   = "external-secrets-operator"
  display_name = "External Secrets Operator Service Account"
  description  = "Service account for External Secrets Operator to access Secret Manager"

  depends_on = [google_project_service.iam]
}

# --- IAM PERMISSIONS FOR SECRET MANAGER ACCESS ---
resource "google_project_iam_member" "external_secrets_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# Minimal permissions for token creation (required for service account keys)
resource "google_project_iam_member" "external_secrets_token_creator" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.external_secrets.email}"
}

# --- SERVICE ACCOUNT KEY FOR K3S (Non-GKE) ---
resource "google_service_account_key" "external_secrets_key" {
  service_account_id = google_service_account.external_secrets.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}
