# ===================================================================
#  ARGOCD BOOTSTRAP - CLEAN VERSION
# ===================================================================

module "shared" {
  source = "../shared"
  providers = {
    google = google.primary
  }
}

# Get tunnel CNAME directly (created by Cloudflare module)
data "google_secret_manager_secret_version" "tunnel_cname" {
  provider = google.primary
  secret   = "tunnel-cname"
}

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
      value = module.shared.argocd_admin_password
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

resource "kubernetes_ingress_v1" "argocd_ingress" {
  provider = kubernetes.k3s_cluster

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

locals {
  argocd_hostname = var.argocd_hostname != "" ? var.argocd_hostname : "argocd.${module.shared.domain}"
}
