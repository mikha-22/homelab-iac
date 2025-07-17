terraform {
  required_version = ">= 1.5.0"
  
  # REMOVED: backend configuration - shared modules shouldn't have backends
  # Individual modules that import this will define their own backends
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
