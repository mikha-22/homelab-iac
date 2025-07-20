
terraform {                          # means we're configuring the terraform for this module
  required_providers {               # setting the providers
    google = {                       # declaring the provider
      source  = "hashicorp/google"   # source is from the org hashicorp, the name of the provider is google
      version = "~> 6.0"             # which version? tilde arrow ~> means stay within this major version 6.x
    }
  }
}

