# ===================================================================
#  CLOUDFLARE TUNNEL - SIMPLIFIED PROVIDERS
# ===================================================================

module "shared" {
  source = "../shared"
}

resource "random_password" "tunnel_secret" {
  length  = 35
  special = false
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "k3s_tunnel" {
  account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
  name       = var.tunnel_name
  secret     = base64encode(random_password.tunnel_secret.result)
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "k3s_tunnel_config" {
  account_id = trimspace(data.google_secret_manager_secret_version.cloudflare_account_id.secret_data)
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

resource "kubernetes_namespace" "cloudflared" {
  metadata {
    name = "cloudflared"
    labels = {
      "app.kubernetes.io/name" = "cloudflared"
    }
  }
}

resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = "external-dns"
    labels = {
      "app.kubernetes.io/name" = "external-dns"
    }
  }
}

resource "kubernetes_secret" "cloudflare_api_token_secret" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.external_dns.metadata[0].name
  }

  data = {
    apiKey = trimspace(data.google_secret_manager_secret_version.cloudflare_api_token.secret_data)
  }
}

resource "helm_release" "external_dns" {
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

resource "kubernetes_secret" "tunnel_credentials" {
  metadata {
    name      = "tunnel-token"
    namespace = kubernetes_namespace.cloudflared.metadata[0].name
  }

  data = {
    token = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  }
}

resource "kubernetes_deployment" "cloudflared" {
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

# Store tunnel CNAME in Secret Manager for other modules
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

resource "google_secret_manager_secret_version" "tunnel_cname_secret_version" {
  secret      = google_secret_manager_secret.tunnel_cname_secret.name
  secret_data = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname

  depends_on = [
    google_secret_manager_secret.tunnel_cname_secret
  ]
}
