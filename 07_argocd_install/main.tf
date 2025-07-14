# --- GOOGLE PROVIDER CONFIGURATION ---
provider "google" {
  project = "homelab-secret-manager"
}

# --- DATA SOURCES FOR SECRETS ---
data "google_secret_manager_secret_version" "argocd_admin_password" {
  secret = "argocd-admin-password"
}

data "google_secret_manager_secret_version" "tunnel_cname" {
  secret = "tunnel-cname"
}

# --- KUBERNETES AND HELM PROVIDERS ---
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes = {
    config_path = var.kubeconfig_path
  }
}

# Create namespace for ArgoCD
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "namespace"
    }
  }
}

# ArgoCD Helm release
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.chart_version

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  # Set admin password if the secret exists and has content
  set_sensitive = [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = trimspace(data.google_secret_manager_secret_version.argocd_admin_password.secret_data)
    }
  ]

  set = [
    {
      name  = "global.domain"
      value = var.argocd_hostname
    },
    {
      name  = "redis-ha.enabled"
      value = tostring(var.redis_ha_enabled)
    }
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 900
}

# CORRECTED FIX: Use a standard Kubernetes Ingress, which ExternalDNS is configured to find.
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
      host = var.argocd_hostname
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
