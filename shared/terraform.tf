terraform {
  required_version = ">= 1.5.0"
  
  # NO backend - child modules don't need backends
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
