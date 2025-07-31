module "shared" {
  source = "../shared"
}

# Get tunnel CNAME directly (created by Cloudflare module)
data "google_secret_manager_secret_version" "tunnel_cname" {
  secret = "tunnel-cname"
}
# Fetch argocd password from GCSM
data "google_secret_manager_secret_version" "argocd_admin_password" {
  secret = "argocd-admin-password"
}
# If var.argocd_hostname not empty, then use var.argocd_hostname as the argocd_hostname
# But if it's empty (Not empty FALSE) then use argocd.milenika.dev
locals {
  argocd_hostname = var.argocd_hostname != "" ? var.argocd_hostname : "argocd.${module.shared.domain}"
}

#Create ArgoCD namespace
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "namespace"
    }
  }
}

# Deploy ArgoCD using helm chart
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.chart_version
  # Render the values from this folder/values/argocd-values.yaml
  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

set_sensitive = [
  {
    # ArgoCD has to use bcrypt as the password
    name  = "configs.secret.argocdServerAdminPassword"
    value = bcrypt(trimspace(data.google_secret_manager_secret_version.argocd_admin_password.secret_data))
  }
]
  
  set = [
    {
      name  = "configs.cm.url"
      value = "https://${local.argocd_hostname}"
    },
    { # This is true because cloudflare handles the TLS termination
      name  = "server.insecure"
      value = var.server_insecure
    },
    { # This is false for a homelab
      name  = "redis-ha.enabled"
      value = var.redis_ha_enabled
    }
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 900
}

# Creeate ArgoCD ingress WITH specific annotations for the ExternalDNS to pick it up and make the zone
# for argocd.milenika.dev
resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" : "traefik",
      "external-dns.alpha.kubernetes.io/target" : trimspace(data.google_secret_manager_secret_version.tunnel_cname.secret_data),
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" : "true"
    }
  }

  spec {
    rule {
      host = local.argocd_hostname
      http {
        path {
          path_type = "Prefix"
          path      = "/"
          backend {
            service {
              name = "argocd-server"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.argocd]
}
