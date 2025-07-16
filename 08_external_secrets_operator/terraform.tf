terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "08_external_secrets_operator"
  }
  
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
      configuration_aliases = [
        helm.k3s_apps
      ]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
      configuration_aliases = [
        kubernetes.k3s_cluster
      ]
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
      configuration_aliases = [
        google.primary
      ]
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
      configuration_aliases = [
        time.scheduling
      ]
    }
  }
}
