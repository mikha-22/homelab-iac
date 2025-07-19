terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_nas/01_base_images"
  }
  
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.70.1"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}
