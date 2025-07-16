# ===================================================================
#  CLOUDFLARE TUNNEL - FULLY CORRECTED CONFIGURATION
#
#  This file includes two critical fixes:
#  1. Correctly configures the ExternalDNS Helm deployment to use a
#     Kubernetes secret for the API token.
#  2. Adds logic to create and populate the 'tunnel-cname' secret
#     in Google Secret Manager for the ArgoCD module to consume.
# ===================================================================

# --- IMPORT SHARED MODULE ---
module "shared" {
  source = "../shared"
}

# --- TUNNEL SECRET ---
resource "random_password" "tunnel_secret" {
  provider = random.generation

  length  = 35
  special = false
}

# --- CLOUDFLARE TUNNEL ---
resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s_tunnel" {
  provider = cloudflare.dns_tunnels

  account_id = module.shared.cloudflare_config.account_id
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "cloudflare"
}

# --- TUNNEL CONFIG ---
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k3s_tunnel_config" {
  provider = cloudflare.dns_tunnels

  account_id = module.shared.cloudflare_config.account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id

  config {
    ingress_rule {
      hostname = "*.${module.shared.domain}"
      service  = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
    }

    ingress_rule {
      hostname = module.shared.domain
      service  = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

# --- KUBERNETES NAMESPACES ---
resource "kubernetes_namespace" "cloudflared" {
  provider = kubernetes.k3s_cluster

  metadata {
    name = "cloudflared"
    labels = {
      "app.kubernetes.io/name" = "cloudflared"
    }
  }
}

resource "kubernetes_namespace" "external_dns" {
  provider = kubernetes.k3s_cluster

  metadata {
    name = "external-dns"
    labels = {
      "app.kubernetes.io/name" = "external-dns"
    }
  }
}

# --- CORRECTED: SECRET FOR EXTERNALDNS API TOKEN ---
# Create a Kubernetes secret to hold the Cloudflare API token.
resource "kubernetes_secret" "cloudflare_api_token_secret" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    apiKey = module.shared.cloudflare_api_token
  }
}

# --- CORRECTED: EXTERNAL DNS HELM RELEASE ---
# This resource is now configured to use the Kubernetes secret for authentication.
resource "helm_release" "external_dns" {
  provider = helm.k3s_apps

  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = kubernetes_namespace.external_dns.metadata[0].name
  version    = "1.14.3"

  values = [
    yamlencode({
      provider = "cloudflare"
      env = [
        {
          name = "CF_API_TOKEN"
          valueFrom = {
            secretKeyRef = {
              name = kubernetes_secret.cloudflare_api_token_secret.metadata[0].name
              key  = "apiKey"
            }
          }
        }
      ]
      sources       = ["ingress"]
      txtOwnerId    = "homelab-k3s"
      policy        = "sync"
      logLevel      = "info"
      interval      = "1m"
      domainFilters = [module.shared.domain]
    })
  ]

  depends_on = [
    kubernetes_secret.cloudflare_api_token_secret
  ]
}

# --- CLOUDFLARED DEPLOYMENT ---
resource "kubernetes_secret" "tunnel_credentials" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = "tunnel-token"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    token = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  }
}

resource "kubernetes_deployment" "cloudflared" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = "cloudflared"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  spec {
    replicas = 2

    selector {
      match_labels = { app = "cloudflared" }
    }

    template {
      metadata {
        labels = { app = "cloudflared" }
      }

      spec {
        container {
          name  = "cloudflared"
          image = "cloudflare/cloudflared:latest"
          args  = ["tunnel", "--no-autoupdate", "run"]

          env {
            name = "TUNNEL_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.tunnel_credentials.metadata[0].name
                key  = "token"
              }
            }
          }
        }
      }
    }
  }
}

# =================================================================
#  NEW: STORE TUNNEL CNAME IN SECRET MANAGER FOR OTHER MODULES
# =================================================================

# Create a secret "slot" for the tunnel CNAME
resource "google_secret_manager_secret" "tunnel_cname_secret" {
  secret_id = "tunnel-cname"

  labels = {
    environment = "homelab"
    managed_by  = "terraform"
    component   = "cloudflare-tunnel"
  }

  replication {
    auto {}
  }
}

# Populate the secret with the actual CNAME value from the created tunnel
resource "google_secret_manager_secret_version" "tunnel_cname_secret_version" {
  secret      = google_secret_manager_secret.tunnel_cname_secret.name
  secret_data = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname

  # Ensure this only runs after the secret slot is created
  depends_on = [
    google_secret_manager_secret.tunnel_cname_secret
  ]
}
