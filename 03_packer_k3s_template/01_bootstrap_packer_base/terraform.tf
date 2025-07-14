terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "03_packer_k3s_template/01_bootstrap_packer_base"
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
