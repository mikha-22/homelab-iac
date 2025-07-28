# Read SSH key file in main.tf, not tfvars
# this is a logic to merge the secrets into a single local value, local.all_secrets
# contains var.secrets (populated by .tfvars for the actual values) with 
# appended ssh keys by processing the path for both, 
locals {
  all_secrets = merge( 
    var.secrets,
    # Add the user SSH key secret if a path is provided
    var.ssh_public_key_path != "" ? { 
      # terraform can handle logical statements, if not empty then do ->
      "nas-vm-ssh-key" = {
        # file() is do shell cat to the file in the path 
        secret_data = file(var.ssh_public_key_path) 
        description = "Public SSH key for all VM user access, managed by Terraform."
      }
    } : {}, # else do nothing
    
    var.proxmox_ssh_private_key_path != "" ? {
      "proxmox-ssh-private-key" = {
        secret_data = file(var.proxmox_ssh_private_key_path)
        description = "Proxmox SSH private key for Terraform authentication"
      }
    } : {}
  )
}
# now local.all_secrets data collection (local value) should be available to use, consists of secrets declared by variables.tf
# populated by terraform.tfvars
  
# --- ENABLE APIS ---
resource "google_project_service" "secretmanager" {
  service = "secretmanager.googleapis.com"
  # it is currently ignored because disable on destroy is set on false  
  disable_dependent_services = true # 
  # This means that if we do terraform destroy, do not actually disable the service/api
  # instead, just remove it from state file
  disable_on_destroy         = false 

}

resource "google_project_service" "iam" {
  service = "iam.googleapis.com"
  # if the disable_on_destroy is set on true, every other service that's dependent on this
  # will also be disabled, e.g. disabling cloud functions also disabling cloud build
  disable_dependent_services = true 
  disable_on_destroy         = false
}

# --- SECRET MANAGER -- CREATE SLOTS FOR SECRETS ---
resource "google_secret_manager_secret" "homelab_secrets" {
  # terraform loop logic, the single object (map) is called by using each.
  for_each = local.all_secrets 
  # each.key means the key e.g. proxmox-api-token key = {value}
  secret_id = each.key 
  
  labels = {
    environment = "homelab"
    managed_by  = "terraform"
    component   = "secrets"
  }
# High Availability, multi region replication
  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager] 
  # executed AFTER the google_project_service.secretmanager resource
}

resource "google_secret_manager_secret_version" "homelab_secret_versions" { 
  # after the slot is created, we populate it with versions containg the secret data
  for_each = local.all_secrets
  # fetch the slot/container name
  secret      = google_secret_manager_secret.homelab_secrets[each.key].name
  # assigns the value of the secret data for that particular secret
  secret_data = each.value.secret_data 
# notice it uses value.secret_data, because secret_data is an attribute which is a
# part of the object value.
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

# ===================================================================
#  Automatically store the generated service account key
# ===================================================================

# Create a dedicated secret "slot" for the service account key
resource "google_secret_manager_secret" "eso_service_account_key" {
  secret_id = "external-secrets-service-account-key"

  labels = {
    environment = "homelab"
    managed_by  = "terraform"
    component   = "secrets"
    automation  = "self-managed"
  }

  replication {
    auto {}
  }

  depends_on = [google_service_account.external_secrets]
}

# Populate the secret with the private key from the generated key resource
resource "google_secret_manager_secret_version" "eso_service_account_key_version" {
  secret      = google_secret_manager_secret.eso_service_account_key.id
  secret_data = base64decode(google_service_account_key.external_secrets_key.private_key)
}
