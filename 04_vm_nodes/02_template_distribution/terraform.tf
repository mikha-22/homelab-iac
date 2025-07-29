terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "04_vm_nodes/02_template_distribution"  # FIXED: was 04_bootstrap_vm_nodes
  }
  
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}
