terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "04_bootstrap_vm_nodes/03_deploy_vm"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
    # null is for custom command
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    # local is for local files, on this module specifically it's used to generate the final ansible inventory
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}
