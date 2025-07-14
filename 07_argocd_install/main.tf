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

  # Use custom values file
  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  # Set admin password if provided
  set_sensitive = var.admin_password != "" ? [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.admin_password
    }
  ] : []

  # Set essential global values
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
# This ensures DNS records are created without changing previous steps.
resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      # Annotation for Traefik to use this Ingress
      "kubernetes.io/ingress.class" : "traefik",
      
      # Annotations for ExternalDNS
      "external-dns.alpha.kubernetes.io/target" : var.tunnel_cname,
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
