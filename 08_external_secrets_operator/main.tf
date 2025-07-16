# ===================================================================
#  EXTERNAL SECRETS OPERATOR - USING KUBERNETES_MANIFEST
# ===================================================================

module "shared" {
  source = "../shared"
  providers = {
    google = google.primary
  }
}

resource "kubernetes_namespace" "external_secrets" {
  provider = kubernetes.k3s_cluster

  metadata {
    name = var.eso_namespace
    labels = {
      "app.kubernetes.io/name"      = "external-secrets"
      "app.kubernetes.io/component" = "namespace"
    }
  }
}

resource "helm_release" "external_secrets" {
  provider = helm.k3s_apps

  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  timeout    = 900

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "replicaCount"
    value = local.eso_config.replicas
  }

  wait = true
  depends_on = [
    kubernetes_namespace.external_secrets
  ]
}

resource "kubernetes_secret" "gcp_service_account" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = var.service_account_secret_k8s_name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  data = {
    "credentials.json" = module.shared.eso_service_account_key
  }

  type = "Opaque"
  
  depends_on = [
    kubernetes_namespace.external_secrets
  ]
}

resource "time_sleep" "wait_for_eso_ready" {
  provider   = time.scheduling
  depends_on = [helm_release.external_secrets]
  create_duration = "120s"
}

# IMPROVED: Use kubernetes_manifest instead of local-exec
resource "kubernetes_manifest" "cluster_secret_store" {
  depends_on = [
    time_sleep.wait_for_eso_ready,
    kubernetes_secret.gcp_service_account
  ]

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = module.shared.gcp_project_id
          auth = {
            secretRef = {
              secretAccessKeySecretRef = {
                name      = kubernetes_secret.gcp_service_account.metadata[0].name
                key       = "credentials.json"
                namespace = kubernetes_namespace.external_secrets.metadata[0].name
              }
            }
          }
        }
      }
    }
  }
}
