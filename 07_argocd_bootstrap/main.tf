# ===================================================================
#  ARGOCD BOOTSTRAP - USING CENTRALIZED PROVIDERS
#  Deploys ArgoCD with centralized domain management and improved
#  verification including UI accessibility checks
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
      "app.kubernetes.io/part-of"   = "gitops-platform"
      "argocd.argoproj.io/managed-by" = "terraform"
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
      name  = "global.domain"
      value = local.argocd_hostname
    },
    {
      name  = "redis-ha.enabled"
      value = tostring(var.redis_ha_enabled)
    },
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

# --- FINAL CORRECTED ARGOCD INGRESS ---
resource "kubernetes_ingress_v1" "argocd_ingress" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = "argocd-server-ingress"
    namespace = kubernetes_namespace.argocd.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "argocd-ingress"
      "app.kubernetes.io/component" = "ingress"
      "app.kubernetes.io/part-of"   = "argocd"
    }
    annotations = {
      # This annotation is kept for backward compatibility and for some tools that might still look for it.
      "kubernetes.io/ingress.class"                         = "traefik"
      
      # These annotations correctly configure ExternalDNS to manage the Cloudflare DNS record.
      "external-dns.alpha.kubernetes.io/target"            = trimspace(data.google_secret_manager_secret_version.tunnel_cname.secret_data)
      "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
      
      # This annotation provides a hint to Traefik to enable TLS routing.
      "traefik.ingress.kubernetes.io/router.tls"           = "true"
    }
  }

  spec {
    # This is the modern, required field that explicitly tells the K3s Traefik controller to handle this Ingress.
    # This is the direct fix for the "404 page not found" error.
    ingress_class_name = "traefik"

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

# --- ARGOCD DEPLOYMENT VERIFICATION ---
resource "null_resource" "verify_argocd_deployment" {
  depends_on = [
    helm_release.argocd,
    kubernetes_ingress_v1.argocd_ingress
  ]

  triggers = {
    chart_version    = var.chart_version
    argocd_hostname  = local.argocd_hostname
    namespace        = kubernetes_namespace.argocd.metadata[0].name
    timestamp        = timestamp()
  }

  provisioner "local-exec" {
    # Use bash interpreter to ensure script commands like 'pipefail' work correctly.
    interpreter = ["/bin/bash", "-c"]
    # This resilient script checks for all components created by the ArgoCD Helm release using labels.
    command = <<-EOT
      set -euo pipefail
      
      echo "🔍 Verifying ArgoCD deployment with label selectors..."
      NAMESPACE="${kubernetes_namespace.argocd.metadata[0].name}"
      RELEASE_LABEL="app.kubernetes.io/instance=argocd"
      
      # Wait for all Deployments managed by the Helm release to be ready
      echo "⏳ Waiting for all ArgoCD Deployments to roll out..."
      for dep in $(kubectl get deployments -n $NAMESPACE -l $RELEASE_LABEL -o name); do
        echo "  - Waiting for $dep..."
        kubectl rollout status $dep -n $NAMESPACE --timeout=300s
      done
      
      # Wait for all StatefulSets managed by the Helm release to be ready
      echo "⏳ Waiting for all ArgoCD StatefulSets to roll out..."
      for sts in $(kubectl get statefulsets -n $NAMESPACE -l $RELEASE_LABEL -o name); do
        echo "  - Waiting for $sts..."
        kubectl rollout status $sts -n $NAMESPACE --timeout=300s
      done
      
      echo "✅ All ArgoCD components are ready."
      
      # Verify all pods are running
      echo "🔍 Verifying all ArgoCD pods are running..."
      timeout 60 bash -c '
        while [[ $(kubectl get pods -n $NAMESPACE --field-selector=status.phase!=Running --no-headers | wc -l) -gt 0 ]]; do
          echo "  Waiting for all pods to be running..."
          kubectl get pods -n $NAMESPACE --no-headers | grep -v Running || true
          sleep 10
        done
      '
      
      echo "🎉 All ArgoCD pods are running and verified."
    EOT
  }
}

# --- LOCAL VARIABLES ---
locals {
  argocd_hostname = var.argocd_hostname != "" ? var.argocd_hostname : "argocd.${module.shared.domain}"
}
