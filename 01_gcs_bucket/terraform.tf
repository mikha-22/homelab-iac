
# Means we're configuring the terraform for this module
terraform {
  # Set version to above 1.5.0 or equal
  required_version = ">= 1.5.0" 
  # setting the providers  
  required_providers {
  # declaring the provider 
  google = {
      # source is from the org hashicorp, the name of the provider is google
      source  = "hashicorp/google"
      # which version? tilde arrow ~> means stay within this major version 6.x
      version = "~> 6.0" 
    }
  }
}

