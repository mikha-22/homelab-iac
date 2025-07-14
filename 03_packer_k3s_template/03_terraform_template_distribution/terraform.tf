terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_packer_k3s_template/03_terraform_template_distribution"
  }
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
