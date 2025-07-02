# =================================================================
#  Terraform Configuration for a Cloudflare Tunnel
#  Manages the tunnel, its routing, and its DNS records.
#  CORRECTED: Re-added random_password for the tunnel secret.
# =================================================================

# --- CONFIGURE PROVIDERS ---
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.20.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure the Cloudflare Provider
# The API token is automatically read from the CLOUDFLARE_API_TOKEN environment variable
provider "cloudflare" {}

# Configure the Kubernetes Provider
# Assumes you have a working kubeconfig file on your machine
provider "kubernetes" {}


# --- INPUT VARIABLES ---
variable "cloudflare_account_id" {
  type        = string
  description = "Your Cloudflare Account ID."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Zone ID for your domain (milenika.dev)."
}

variable "tunnel_name" {
  type        = string
  description = "A name for your Cloudflare Tunnel."
  default     = "homelab-k3s-tunnel"
}

variable "k8s_namespace" {
  type        = string
  description = "The Kubernetes namespace where your cloudflared deployment is running."
  default     = "cloudflare"
}


# --- RESOURCE DEFINITIONS ---

# 1. Generate a secure secret for the tunnel (This was mistakenly removed)
resource "random_password" "tunnel_secret" {
  length  = 35
  special = false
}

# 2. Create the Cloudflare Tunnel itself
# The 'secret' argument is required here.
resource "cloudflare_tunnel" "k3s_tunnel" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
}

# 3. Create the Kubernetes secret for the cloudflared pods to use
# This secret contains the credentials.json file needed for authentication.
resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-credentials" # This name MUST match what your deployment expects
    namespace = var.k8s_namespace
  }

  data = {
    "credentials.json" = jsonencode({
      "AccountId"    = var.cloudflare_account_id
      "TunnelID"     = cloudflare_tunnel.k3s_tunnel.id
      "TunnelName"   = cloudflare_tunnel.k3s_tunnel.name
      # This must use the result from the 'random_password' resource
      "TunnelSecret" = random_password.tunnel_secret.result
    })
  }
}

# 4. Configure the tunnel's ingress rules (traffic routing)
resource "cloudflare_tunnel_config" "k3s_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_tunnel.k3s_tunnel.id

  # depends_on is a good practice to ensure the Kubernetes
  # secret is created before the tunnel config is finalized.
  depends_on = [kubernetes_secret.tunnel_credentials]

  config {
    ingress_rule {
      hostname = "*.milenika.dev"
      service  = "http://traefik-proxy.traefik.svc.cluster.local:80"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

# 5. Create the public DNS CNAME record to point your domain to the tunnel
resource "cloudflare_record" "wildcard_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "*.milenika.dev"
  # Using 'content' instead of 'value' to fix the deprecation warning
  content = cloudflare_tunnel.k3s_tunnel.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform: Points wildcard traffic to the k3s tunnel."
}
