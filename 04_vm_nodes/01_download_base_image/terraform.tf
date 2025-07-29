terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "04_vm_nodes/01_download_base_image"  # FIXED: was 04_bootstrap_vm_nodes
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
  }
}
