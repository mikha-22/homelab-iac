# ===================================================================
#  EXTERNAL SECRETS OPERATOR - SIMPLIFIED VERSION
# ===================================================================

# --- IMPORT SHARED CONFIGURATION ---
module "shared" {
  source = "../shared"
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
  
  depends_on = [
    kubernetes_namespace.external_secrets
  ]
}

# --- WAIT FOR ESO TO BE READY ---
resource "time_sleep" "wait_for_eso_ready" {
  provider   = time.scheduling
  depends_on = [helm_release.external_secrets]
  create_duration = "120s"
}

# --- CREATE CLUSTERSECRETSTORE USING KUBECTL ---
resource "null_resource" "cluster_secret_store" {
  depends_on = [
    time_sleep.wait_for_eso_ready,
    kubernetes_secret.gcp_service_account
  ]

  triggers = {
    store_name = var.cluster_secret_store_name
    project_id = module.shared.gcp_project_id
    secret_name = kubernetes_secret.gcp_service_account.metadata[0].name
    namespace = kubernetes_namespace.external_secrets.metadata[0].name
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🔧 Creating ClusterSecretStore using kubectl..."
      
      # Create temporary YAML file
      cat > /tmp/cluster-secret-store.yaml << 'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: ${var.cluster_secret_store_name}
spec:
  provider:
    gcpsm:
      projectID: "${module.shared.gcp_project_id}"
      auth:
        secretRef:
          secretAccessKeySecretRef:
            name: "${kubernetes_secret.gcp_service_account.metadata[0].name}"
            key: "credentials.json"
            namespace: "${kubernetes_namespace.external_secrets.metadata[0].name}"
EOF
      
      # Apply the ClusterSecretStore
      kubectl apply -f /tmp/cluster-secret-store.yaml
      
      # Clean up
      rm -f /tmp/cluster-secret-store.yaml
      
      echo "✅ ClusterSecretStore ${var.cluster_secret_store_name} created successfully"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    interpreter = ["/bin/bash", "-c"]
    command = <<-EOT
      echo "🧹 Removing ClusterSecretStore..."
      kubectl delete clustersecretstore ${self.triggers.store_name} --ignore-not-found=true || true
      echo "✅ ClusterSecretStore cleanup complete"
    EOT
  }
}
