terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "02_create_nas/02_nas_vm"
  }
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
    # ADD THIS BLOCK
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
