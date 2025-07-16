# ===================================================================
#  EXTERNAL SECRETS OPERATOR - MAIN CONFIGURATION
# ===================================================================

# --- IMPORT SHARED CONFIGURATION ---
module "shared" {
  source = "../shared"
  # ADD THIS PROVIDERS BLOCK TO FIX THE "project: required" ERROR
  providers = {
    google = google.primary
  }
}

# --- CREATE NAMESPACE ---
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

# --- INSTALL CRDS FIRST ---
resource "null_resource" "install_crds" {
  depends_on = [kubernetes_namespace.external_secrets]

  triggers = {
    eso_version = var.eso_chart_version
    namespace   = kubernetes_namespace.external_secrets.metadata[0].name
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -euo pipefail
      echo "🔧 Installing External Secrets Operator CRDs..."
      kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v${var.eso_chart_version}/deploy/crds/bundle.yaml
      echo "⏳ Waiting for CRDs to be established..."
      kubectl wait --for condition=established --timeout=60s crd/externalsecrets.external-secrets.io
      kubectl wait --for condition=established --timeout=60s crd/secretstores.external-secrets.io
      kubectl wait --for condition=established --timeout=60s crd/clustersecretstores.external-secrets.io
      echo "✅ CRDs installed and established"
    EOT
  }
}

# --- WAIT FOR CRDS TO BE RECOGNIZED ---
resource "time_sleep" "wait_for_crds" {
  provider   = time.scheduling
  depends_on = [null_resource.install_crds]
  create_duration = "30s"
}

# --- DEPLOY ESO HELM CHART ---
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
    value = "false"
  }

  wait = true
  depends_on = [
    time_sleep.wait_for_crds
  ]
}

# --- CREATE SERVICE ACCOUNT SECRET ---
resource "kubernetes_secret" "gcp_service_account" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = var.service_account_secret_k8s_name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  data = {
    "credentials.json" = data.google_secret_manager_secret_version.service_account_key.secret_data
  }

  type = "Opaque"
}

# --- WAIT FOR ESO TO BE READY BEFORE CREATING THE STORE ---
resource "time_sleep" "wait_for_eso" {
  provider   = time.scheduling
  depends_on = [helm_release.external_secrets]
  create_duration = "60s"
}

# --- CREATE CLUSTERSECRETSTORE ---
resource "kubernetes_manifest" "cluster_secret_store" {
  provider = kubernetes.k3s_cluster
  
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

  depends_on = [
    time_sleep.wait_for_eso,
    kubernetes_secret.gcp_service_account
  ]
}
