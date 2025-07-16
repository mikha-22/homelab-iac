# ===================================================================
#  SHARED TERRAFORM VERSIONS AND PROVIDER REQUIREMENTS
#  Only require providers that the shared module actually uses
# ===================================================================

terraform {
  required_version = ">= 1.5.0"
  
  # This shared module doesn't use a backend since it's local
  # Individual modules that import this will define their own backends
  
  required_providers {
    # Google Cloud provider - actually used by shared module for secret access
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    
    # NOTE: Other providers are NOT required by the shared module itself
    # Individual modules declare what THEY need in their own terraform.tf
    # This prevents forcing every module to provide unused providers
  }
}

# --- VERSION CONSTRAINTS FOR REFERENCE ---
# These are recommended versions for use across the homelab
# Individual modules should copy these to their terraform.tf files

locals {
  recommended_provider_versions = {
    google     = "~> 6.0"
    proxmox    = "~> 0.70.1"
    kubernetes = "~> 2.32"
    helm       = "~> 2.15"
    cloudflare = "~> 4.0"
    null       = "~> 3.2"
    random     = "~> 3.5"
    time       = "~> 0.12"
  }
  
  # Minimum Terraform version for all modules
  min_terraform_version = "1.5.0"
}
