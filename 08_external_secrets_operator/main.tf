# ===================================================================
#  EXTERNAL SECRETS OPERATOR - USING CENTRALIZED PROVIDERS
#  Deploys ESO with centralized configuration and improved verification
# ===================================================================

# --- IMPORT SHARED CONFIGURATION ---
module "shared" {
  source = "../shared"
}

# --- DATA SOURCES ---
data "google_secret_manager_secret_version" "service_account_key" {
  provider = google.primary
  secret = var.service_account_secret_name
}

# --- CREATE NAMESPACE ---
resource "kubernetes_namespace" "external_secrets" {
  provider = kubernetes.k3s_cluster

  metadata {
    name = var.eso_namespace
    labels = {
      "app.kubernetes.io/name"      = "external-secrets"
      "app.kubernetes.io/component" = "namespace"
      "app.kubernetes.io/part-of"   = "platform-foundation"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

# --- INSTALL CRDs FIRST ---
resource "null_resource" "install_crds" {
  depends_on = [kubernetes_namespace.external_secrets]

  triggers = {
    eso_version = var.eso_chart_version
    namespace   = kubernetes_namespace.external_secrets.metadata[0].name
    timestamp   = timestamp()
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

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      echo "🧹 Removing External Secrets Operator CRDs..."
      kubectl delete -f https://raw.githubusercontent.com/external-secrets/external-secrets/v${self.triggers.eso_version}/deploy/crds/bundle.yaml --ignore-not-found=true || echo "CRDs already removed"
    EOT
  }
}

# --- WAIT FOR CRDs ---
resource "time_sleep" "wait_for_crds" {
  provider = time.scheduling
  depends_on = [null_resource.install_crds]
  
  create_duration = "30s"
}

# --- DEPLOY ESO HELM CHART ---
resource "helm_release" "external_secrets" {
  provider = helm.k3s_apps

  name       = "external-secrets"
  repository = "https://external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  timeout    = 900

  # Disable CRD installation since we handle it separately
  set {
    name  = "installCRDs"
    value = "false"
  }

  values = [
    yamlencode({
      # Main controller configuration
      resources = merge(
        {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        },
        var.enable_monitoring ? {
          # Additional resources for monitoring
          limits = {
            cpu    = "300m"
            memory = "384Mi"
          }
        } : {}
      )
      
      # Security context
      securityContext = {
        allowPrivilegeEscalation = false
        capabilities = {
          drop = ["ALL"]
        }
        readOnlyRootFilesystem = true
        runAsNonRoot = true
        runAsUser = 65534
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
      
      # Pod security context
      podSecurityContext = {
        fsGroup = 65534
        runAsNonRoot = true
        seccompProfile = {
          type = "RuntimeDefault"
        }
      }
      
      # ServiceMonitor for Prometheus
      serviceMonitor = {
        enabled = var.enable_monitoring
        additionalLabels = var.enable_monitoring ? {
          release = "prometheus-stack"
        } : {}
      }
      
      # Webhook configuration
      webhook = {
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
      
      # Certificate controller
      certController = {
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
      
      # Replica configuration
      replicaCount = var.enable_ha ? 2 : 1
      
      # Environment-specific settings
      env = {
        LOG_LEVEL = var.enable_monitoring ? "debug" : "info"
      }
    })
  ]

  # Wait for deployment to be ready
  wait          = true
  wait_for_jobs = true

  depends_on = [
    kubernetes_namespace.external_secrets,
    time_sleep.wait_for_crds
  ]
}

# --- CREATE SERVICE ACCOUNT SECRET ---
resource "kubernetes_secret" "gcp_service_account" {
  provider = kubernetes.k3s_cluster

  metadata {
    name      = var.service_account_secret_k8s_name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "gcp-service-account"
      "app.kubernetes.io/component" = "authentication"
      "app.kubernetes.io/part-of"   = "external-secrets"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  data = {
    "service-account-key" = data.google_secret_manager_secret_version.service_account_key.secret_data
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.external_secrets]
}

# --- WAIT FOR ESO TO BE READY ---
resource "time_sleep" "wait_for_eso" {
  provider = time.scheduling
  depends_on = [helm_release.external_secrets]
  
  create_duration = "60s"
}

# --- CREATE CLUSTERSECRETSTORE ---
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
      labels = {
        "app.kubernetes.io/name"      = "gcp-secret-store"
        "app.kubernetes.io/component" = "secret-store"
        "app.kubernetes.io/part-of"   = "external-secrets"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = module.shared.gcp_project_id
          auth = {
            secretRef = {
              secretAccessKeySecretRef = {
                name      = kubernetes_secret.gcp_service_account.metadata[0].name
                key       = "service-account-key"
                namespace = kubernetes_namespace.external_secrets.metadata[0].name
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_secret.gcp_service_account,
    time_sleep.wait_for_eso
  ]
}
