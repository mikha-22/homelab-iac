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

# ConfigMap for insecure server configuration (Cloudflare compatibility)
resource "kubernetes_config_map" "argocd_cmd_params" {
  metadata {
    name      = "argocd-cmd-params-cm"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"    = "argocd-cmd-params-cm"
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    # Enable insecure mode for Cloudflare TLS termination
    "server.insecure" = "true"
    
    # Additional recommended settings
    "server.disable.auth"                = "false"
    "server.enable.proxy.extension"      = "true"
    "application.instanceLabelKey"       = "argocd.argoproj.io/instance"
    "server.rootpath"                    = "/"
    "server.log.level"                   = "info"
  }

  depends_on = [kubernetes_namespace.argocd]
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

  # Override values with variables using the new syntax
  set = [
    {
      name  = "global.domain"
      value = var.argocd_hostname
    },
    {
      name  = "redis-ha.enabled"
      value = var.redis_ha_enabled
    }
  ]

  # Set admin password if provided using set_sensitive
  set_sensitive = var.admin_password != "" ? [
    {
      name  = "configs.secret.argocdServerAdminPassword"
      value = var.admin_password
    }
  ] : []

  # Ensure configmap is created first
  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_config_map.argocd_cmd_params
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600
}

# Create ingress for ArgoCD with ExternalDNS annotations
resource "kubernetes_ingress_v1" "argocd_ingress" {
  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    annotations = {
      # ExternalDNS configuration
      "external-dns.alpha.kubernetes.io/target"           = var.tunnel_cname
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
      
      # Traefik annotations for your K3s setup
      "traefik.ingress.kubernetes.io/router.entrypoints" = "web,websecure"
      "traefik.ingress.kubernetes.io/router.tls"         = "true"
      
      # ArgoCD specific annotations
      "nginx.ingress.kubernetes.io/force-ssl-redirect"   = "false"
      "nginx.ingress.kubernetes.io/backend-protocol"     = "HTTP"
    }
    labels = {
      "app.kubernetes.io/name"      = "argocd-server"
      "app.kubernetes.io/component" = "ingress"
    }
  }

  spec {
    rule {
      host = var.argocd_hostname
      http {
        path {
          path      = "/"
          path_type = "Prefix"
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

# Service for better integration (optional, for monitoring)
resource "kubernetes_service" "argocd_server_monitoring" {
  metadata {
    name      = "argocd-server-metrics"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "argocd-server"
      "app.kubernetes.io/component" = "metrics"
    }
  }

  spec {
    type = "ClusterIP"
    
    port {
      name        = "metrics"
      port        = 8083
      target_port = 8083
      protocol    = "TCP"
    }

    selector = {
      "app.kubernetes.io/component" = "server"
      "app.kubernetes.io/name"      = "argocd-server"
    }
  }

  depends_on = [helm_release.argocd]
}
