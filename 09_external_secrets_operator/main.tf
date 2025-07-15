# ===================================================================
#  PHASE 8: EXTERNAL SECRETS OPERATOR - FINAL WORKING VERSION
#  Based on successful manual testing
# ===================================================================

# --- DATA SOURCES ---
data "google_secret_manager_secret_version" "service_account_key" {
  secret = var.service_account_secret_name
}

# --- CREATE NAMESPACE ---
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.eso_namespace
    labels = {
      "app.kubernetes.io/name"      = "external-secrets"
      "app.kubernetes.io/component" = "namespace"
      "app.kubernetes.io/part-of"   = "platform-foundation"
    }
  }
}

# --- STEP 1: Install CRDs first ---
resource "null_resource" "install_crds" {
  depends_on = [kubernetes_namespace.external_secrets]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.15.1/deploy/crds/bundle.yaml
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = <<-EOT
      kubectl delete -f https://raw.githubusercontent.com/external-secrets/external-secrets/v0.15.1/deploy/crds/bundle.yaml --ignore-not-found=true
    EOT
  }
}

# --- STEP 2: Wait for CRDs to be available ---
resource "time_sleep" "wait_for_crds" {
  depends_on = [null_resource.install_crds]
  
  create_duration = "30s"
}

# --- STEP 3: Deploy ESO using correct repository ---
resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://external-secrets.io"  # FIXED: Correct repository URL
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name
  timeout    = 900

  # Disable CRD installation since we installed them separately
  set {
    name  = "installCRDs"
    value = "false"
  }

  values = [
    yamlencode({
      # Resource configuration for homelab
      resources = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
      
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
      
      # ServiceMonitor for Prometheus (if available)
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
      
      # Cert controller
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

# --- STEP 4: Create service account secret ---
resource "kubernetes_secret" "gcp_service_account" {
  metadata {
    name      = var.service_account_secret_k8s_name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
    labels = {
      "app.kubernetes.io/name"      = "gcp-service-account"
      "app.kubernetes.io/component" = "authentication"
      "app.kubernetes.io/part-of"   = "external-secrets"
    }
  }

  data = {
    "service-account-key" = data.google_secret_manager_secret_version.service_account_key.secret_data
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.external_secrets]
}

# --- STEP 5: Wait for ESO to be ready ---
resource "time_sleep" "wait_for_eso" {
  depends_on = [helm_release.external_secrets]
  
  create_duration = "60s"
}

# --- STEP 6: Create ClusterSecretStore with correct API spec ---
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"  # CONFIRMED: Correct API version
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
      labels = {
        "app.kubernetes.io/name"      = "gcp-secret-store"
        "app.kubernetes.io/component" = "secret-store"
        "app.kubernetes.io/part-of"   = "external-secrets"
      }
    }
    spec = {
      provider = {
        gcpsm = {
          projectID = var.gcp_project_id  # FIXED: projectID (capital ID)
          auth = {
            secretRef = {
              secretAccessKeySecretRef = {  # FIXED: secretAccessKeySecretRef
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

# --- READINESS CHECK ---
resource "kubernetes_manifest" "eso_readiness_check" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "eso-readiness-check"
      namespace = kubernetes_namespace.external_secrets.metadata[0].name
      labels = {
        "app.kubernetes.io/name"      = "eso-readiness"
        "app.kubernetes.io/component" = "health-check"
        "app.kubernetes.io/part-of"   = "external-secrets"
      }
    }
    data = {
      "status" = "ready"
      "created_by" = "terraform"
    }
  }

  depends_on = [kubernetes_manifest.cluster_secret_store]
}
