# =================================================================
#  FINAL, CORRECTED TERRAFORM CONFIGURATION
# =================================================================

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
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure providers
provider "cloudflare" {}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

# Variables
variable "cloudflare_account_id" {
  type        = string
  description = "Your Cloudflare Account ID."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Zone ID for your domain (milenika.dev)."
}

variable "cloudflare_api_token_externaldns" {
  type        = string
  description = "Cloudflare API token for ExternalDNS"
  sensitive   = true
}

variable "tunnel_name" {
  type        = string
  description = "A name for your Cloudflare Tunnel."
  default     = "homelab-k3s-tunnel"
}

variable "domain_name" {
  type        = string
  description = "Your domain name"
  default     = "milenika.dev"
}

variable "traefik_service_name" {
  type        = string
  description = "Traefik service name"
  default     = "traefik"
}

variable "traefik_namespace" {
  type        = string
  description = "Traefik namespace"
  default     = "kube-system"
}

# 1. Generate tunnel secret
resource "random_password" "tunnel_secret" {
  length  = 35
  special = false
}

# 2. Create Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s_tunnel" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "cloudflare"
}

# 3. Configure tunnel routing
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k3s_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id

  config {
    # This is the final catch-all. If a request makes it to the tunnel
    # without a hostname that Traefik recognizes, it will get a 404.
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# 4. Create DNS record for the ROOT domain only
# The wildcard DNS record is now gone.
resource "cloudflare_record" "root_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform: Root domain DNS for tunnel"
}

# 5. Create namespace for cloudflared
resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
  }
}

# 6. Create namespace for external-dns
resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

# 7. Create ExternalDNS secret
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    apiKey = var.cloudflare_api_token_externaldns
  }
}

# 8. Deploy ExternalDNS (Correctly configured)
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    yamlencode({
      provider = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.cloudflare_api_token.metadata[0].name
              key  = "apiKey"
            }
          }
        }
      ]
      # This tells ExternalDNS to ONLY get instructions from Ingress objects.
      sources = ["ingress"]
      txtOwnerId = "homelab-k3s"
      policy = "sync"
      logLevel = "info"
      interval = "1m"
      txtPrefix = "externaldns-"
      domainFilters = [var.domain_name]
    })
  ]

  depends_on = [kubernetes_secret.cloudflare_api_token]
}

# 9. Create tunnel credentials secret for cloudflared
resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-token"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    token = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  }
}

# 10. Deploy cloudflared
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      matchLabels = {
        app = "cloudflared"
      }
    }
    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }
      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"
          args = [
            "tunnel",
            "--no-autoupdate",
            "run"
          ]
          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_credentials.metadata[0].name
                key  = "token"
              }
            }
          }
          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
          liveness_probe {
            tcp_socket {
              port = 20241
            }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
          readiness_probe {
            tcp_socket {
              port = 20241
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret.tunnel_credentials,
    cloudflare_zero_trust_tunnel_cloudflared_config.k3s_tunnel_config
  ]
}

# Outputs
output "tunnel_id" {
  description = "The ID of the created tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
}

output "tunnel_cname" {
  description = "The CNAME of the tunnel for DNS configuration"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
}

output "tunnel_token" {
  description = "The tunnel token (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  sensitive   = true
}

output "setup_complete" {
  description = "Complete setup summary"
  value = {
    tunnel_created    = "✅ Tunnel: ${cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name}"
    external_dns      = "✅ ExternalDNS: Deployed in ${kubernetes_namespace.external_dns.metadata[0].name} namespace"
    cloudflared       = "✅ Cloudflared: 2 replicas running in ${kubernetes_namespace.cloudflared.metadata[0].name} namespace"
    next_steps        = "Deploy your apps with ingress annotations!"
  }
# =================================================================
#  FINAL, CORRECTED TERRAFORM CONFIGURATION
# =================================================================

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
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Configure providers
provider "cloudflare" {}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
}

# Variables
variable "cloudflare_account_id" {
  type        = string
  description = "Your Cloudflare Account ID."
}

variable "cloudflare_zone_id" {
  type        = string
  description = "The Zone ID for your domain (milenika.dev)."
}

variable "cloudflare_api_token_externaldns" {
  type        = string
  description = "Cloudflare API token for ExternalDNS"
  sensitive   = true
}

variable "tunnel_name" {
  type        = string
  description = "A name for your Cloudflare Tunnel."
  default     = "homelab-k3s-tunnel"
}

variable "domain_name" {
  type        = string
  description = "Your domain name"
  default     = "milenika.dev"
}

variable "traefik_service_name" {
  type        = string
  description = "Traefik service name"
  default     = "traefik"
}

variable "traefik_namespace" {
  type        = string
  description = "Traefik namespace"
  default     = "kube-system"
}

# 1. Generate tunnel secret
resource "random_password" "tunnel_secret" {
  length  = 35
  special = false
}

# 2. Create Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s_tunnel" {
  account_id = var.cloudflare_account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "cloudflare"
}

# 3. Configure tunnel routing
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k3s_tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id

  config {
    # This ingress rule is still useful as a catch-all for any traffic
    # that hits the tunnel directly without a specific hostname rule.
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# 4. Create DNS record for the ROOT domain only
# --- The wildcard DNS record has been REMOVED ---
resource "cloudflare_record" "root_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  content = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
  type    = "CNAME"
  proxied = true
  comment = "Managed by Terraform: Root domain DNS for tunnel"
}

# 5. Create namespace for cloudflared
resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
  }
}

# 6. Create namespace for external-dns
resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
  }
}

# 7. Create ExternalDNS secret
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-key"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    apiKey = var.cloudflare_api_token_externaldns
  }
}

# 8. Deploy ExternalDNS
resource "helm_release" "external_dns" {
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name

  values = [
    yamlencode({
      provider = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.cloudflare_api_token.metadata[0].name
              key  = "apiKey"
            }
          }
        }
      ]
      sources = ["ingress", "service"]
      txtOwnerId = "homelab-k3s"
      policy = "sync"
      logLevel = "info"
      interval = "1m"
      txtPrefix = "externaldns-"
      domainFilters = [var.domain_name]
    })
  ]

  depends_on = [kubernetes_secret.cloudflare_api_token]
}

# 9. Create tunnel credentials secret for cloudflared
resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-token"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    token = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  }
}

# 10. Deploy cloudflared
resource "kubernetes_deployment" "cloudflared" {
  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "cloudflared"
      }
    }
    template {
      metadata {
        labels = {
          app = "cloudflared"
        }
      }
      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"
          args = [
            "tunnel",
            "--no-autoupdate",
            "run"
          ]
          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_credentials.metadata[0].name
                key  = "token"
              }
            }
          }
          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }
          liveness_probe {
            tcp_socket {
              port = 20241
            }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
          readiness_probe {
            tcp_socket {
              port = 20241
            }
            initial_delay_seconds = 15
            period_seconds        = 10
          }
        }
      }
    }
  }
  depends_on = [
    kubernetes_secret.tunnel_credentials,
    cloudflare_zero_trust_tunnel_cloudflared_config.k3s_tunnel_config
  ]
}

# Outputs
output "tunnel_id" {
  description = "The ID of the created tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
}

output "tunnel_cname" {
  description = "The CNAME of the tunnel for DNS configuration"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
}

output "tunnel_token" {
  description = "The tunnel token (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  sensitive   = true
}

output "setup_complete" {
  description = "Complete setup summary"
  value = {
    tunnel_created    = "✅ Tunnel: ${cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name}"
    external_dns      = "✅ ExternalDNS: Deployed in ${kubernetes_namespace.external_dns.metadata[0].name} namespace"
    cloudflared       = "✅ Cloudflared: 2 replicas running in ${kubernetes_namespace.cloudflared.metadata[0].name} namespace"
    next_steps        = "Deploy your apps with ingress annotations!"
  }
}
}
