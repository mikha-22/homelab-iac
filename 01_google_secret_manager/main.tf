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
  for_each = var.secrets

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
  for_each = var.secrets

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
