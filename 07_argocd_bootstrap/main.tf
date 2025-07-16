# ===================================================================
#  ARGOCD BOOTSTRAP - FINAL WORKING CONFIGURATION
#  This version uses the Ingress configuration that is proven to work
#  in your specific K3s environment, integrated into your repo structure.
# ===================================================================

# --- IMPORT SHARED CONFIGURATION ---
module "shared" {
  source = "../shared"
  providers = {
    google = google.primary
  }
}

# --- ARGOCD NAMESPACE ---
resource "kubernetes_namespace" "argocd" {
  provider = kubernetes.k3s_cluster
  metadata {
    name = var.argocd_namespace
    labels = {
      "app.kubernetes.io/name"      = "argocd"
      "app.kubernetes.io/component" = "namespace"
    }
  }
}

# --- ARGOCD HELM RELEASE ---
resource "helm_release" "argocd" {
  provider = helm.k3s_apps

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = var.chart_version

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  set_sensitive = [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = trimspace(data.google_secret_manager_secret_version.argocd_admin_password.secret_data)
    }
  ]

  set = [
    {
      name  = "configs.cm.url"
      value = "https://${local.argocd_hostname}"
    }
  ]

  depends_on = [
    kubernetes_namespace.argocd
  ]

  wait          = true
  wait_for_jobs = true
  timeout       = 900
}

# --- PROVEN WORKING INGRESS CONFIGURATION ---
# This Ingress resource uses the exact annotations and structure
# from your working commit.
resource "kubernetes_ingress_v1" "argocd_ingress" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      # This annotation is what your Traefik controller understands.
      "kubernetes.io/ingress.class" : "traefik",
      
      # These annotations explicitly tell ExternalDNS what to do.
      "external-dns.alpha.kubernetes.io/target" : trimspace(data.google_secret_manager_secret_version.tunnel_cname.secret_data),
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" : "true"
    }
  }

  spec {
    # NO ingressClassName is included, matching the working version.
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

# --- LOCAL VARIABLES ---
locals {
  argocd_hostname = var.argocd_hostname != "" ? var.argocd_hostname : "argocd.${module.shared.domain}"
}
