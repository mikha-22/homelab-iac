# Load shared module
module "shared" {
  source = "../shared"
}

# Create external secrets namespace
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.eso_namespace
    labels = {
      "app.kubernetes.io/name"      = "external-secrets"
      "app.kubernetes.io/component" = "namespace"
    }
  }
}

# Deploy the external_secrets using helm chart
resource "helm_release" "external_secrets" {
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
    value = var.enable_ha ? 2 : 1
  }

  wait = true
  depends_on = [
    kubernetes_namespace.external_secrets
  ]
}

# GCP Service Account secrets, fetching from GCSM
resource "kubernetes_secret" "gcp_service_account" {
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

# Wait 2 mins for ESO
resource "time_sleep" "wait_for_eso_ready" {
  depends_on = [helm_release.external_secrets]
  create_duration = "120s"
}

# Render the ClusterSecretStore YAML
locals {
  cluster_secret_store_yaml = templatefile("${path.module}/cluster-secret-store.yaml.tpl", {
    cluster_secret_store_name   = var.cluster_secret_store_name
    gcp_project_id             = module.shared.gcp_project_id
    service_account_secret_name = kubernetes_secret.gcp_service_account.metadata[0].name
    namespace                  = kubernetes_namespace.external_secrets.metadata[0].name
  })
}

# Create ClusterSecretStore using kubectl (more reliable for CRDs)
resource "null_resource" "cluster_secret_store" {
  depends_on = [
    time_sleep.wait_for_eso_ready,
    kubernetes_secret.gcp_service_account
  ]

  triggers = {
    yaml_content = md5(local.cluster_secret_store_yaml)
    store_name   = var.cluster_secret_store_name
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Creating ClusterSecretStore..."
      
      # Wait for CRDs to be available
      timeout 120 bash -c 'while ! kubectl get crd clustersecretstores.external-secrets.io >/dev/null 2>&1; do sleep 5; done'
      
      # Apply the rendered YAML
      echo '${local.cluster_secret_store_yaml}' | kubectl apply -f -
      
      echo "ClusterSecretStore created successfully"
    EOT
  }

  provisioner "local-exec" {
    when = destroy
    command = "kubectl delete clustersecretstore ${self.triggers.store_name} --ignore-not-found=true || true"
  }
}
