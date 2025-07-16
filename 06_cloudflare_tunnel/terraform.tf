terraform {
  required_version = ">= 1.5.0"
  
  backend "gcs" {
    bucket = "homelab-terraform-state-shared"
    prefix = "06_cloudflare_tunnel"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
      configuration_aliases = [
        cloudflare.dns_tunnels
      ]
    }
    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
      configuration_aliases = [
        kubernetes.k3s_cluster
      ]
    }
    
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
      configuration_aliases = [
        helm.k3s_apps
      ]
    }
    
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
      configuration_aliases = [
        random.generation
      ]
    }
  }
}
