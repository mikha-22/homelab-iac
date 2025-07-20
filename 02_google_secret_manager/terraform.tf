terraform {
  required_version = ">= 1.5.0" # minimum 1.5.0, get newer if possible
  
  backend "gcs" { # declares a gcs bucket as backend to store state file
    bucket = "homelab-terraform-state-shared" # the bucket name
    prefix = "02_google_secret_manager" # prefix for this specific module, name is set to match folder for easy
                                        # identification
  }
  
  required_providers { # defines providers
    google = { # creates a google provider
      source  = "hashicorp/google" # source is from the org hashicorp, name of provider is google
      version = "~> 6.0" # stay within the 6.0 major version
    }
  }
}
