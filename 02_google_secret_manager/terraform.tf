terraform {
  # minimum 1.5.0, get newer if possible
  required_version = ">= 1.5.0" 
  # declares a gcs bucket as backend to store state file
  backend "gcs" { 
    # the bucket name
    bucket = "homelab-terraform-state-shared"
    # prefix for this specific module, name is set to match folder for easy identification
    prefix = "02_google_secret_manager" 
  }
  # defines providers
  required_providers {
    # creates a google provider
    google = { 
      # source is from the org hashicorp, name of provider is google
      source  = "hashicorp/google"
      # stay within the 6.0 major version
      version = "~> 6.0" 
    }
  }
}
