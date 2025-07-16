terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "07_argocd_bootstrap"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
      configuration_aliases = [
        google.primary
      ]
    }
    
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0.2"  # Updated to latest version
      configuration_aliases = [
        helm.k3s_apps
      ]
    }
    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
      configuration_aliases = [
        kubernetes.k3s_cluster
      ]
    }
  }
}
