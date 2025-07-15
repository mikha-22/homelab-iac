# =================================================================
#  FINAL, CORRECTED TERRAFORM CONFIGURATION
# =================================================================

# --- DATA SOURCES FOR SECRETS ---
data "google_secret_manager_secret_version" "cloudflare_api_token" {
  secret = "cloudflare-api-token"
}
data "google_secret_manager_secret_version" "cloudflare_account_id" {
  secret = "cloudflare-account-id"
}

# --- RESOURCES ---

# 1. Generate tunnel secret
resource "random_password" "tunnel_secret" {
  length  = 35
  special = false
}

# 2. Create Cloudflare Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s_tunnel" {
  account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "cloudflare"
}

# 3. Configure tunnel routing
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k3s_tunnel_config" {
  account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id

  config {
    ingress_rule {
      hostname = "*.${var.domain_name}"
      service  = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
    }
    ingress_rule {
      hostname = var.domain_name
      service  = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
    }
    ingress_rule {
      service = "http_status:404"
    }
  }
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
    apiKey = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
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
            limits = { cpu = "100m", memory = "128Mi" }
            requests = { cpu = "50m", memory = "64Mi" }
          }
          liveness_probe {
            tcp_socket { port = 20241 }
            initial_delay_seconds = 15
            period_seconds        = 30
          }
          readiness_probe {
            tcp_socket { port = 20241 }
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

# =================================================================
#  NEW: STORE GENERATED OUTPUTS IN SECRET MANAGER
# =================================================================

# 11. Create a secret "slot" for the tunnel CNAME
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

# 12. Populate the secret with the actual CNAME value from the created tunnel
resource "google_secret_manager_secret_version" "tunnel_cname_secret_version" {
  secret      = google_secret_manager_secret.tunnel_cname_secret.name
  secret_data = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname

  # Ensure this only runs after the secret slot is created
  depends_on = [
    google_secret_manager_secret.tunnel_cname_secret
  ]
}
