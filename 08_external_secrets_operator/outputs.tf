# ===================================================================
#  EXTERNAL SECRETS OPERATOR OUTPUTS - ESSENTIAL ONLY
# ===================================================================

output "external_secrets" {
  description = "External Secrets Operator information"
  value = {
    namespace            = kubernetes_namespace.external_secrets.metadata[0].name
    cluster_secret_store = var.cluster_secret_store_name
    chart_version        = helm_release.external_secrets.version
  }
}

output "usage_example" {
  description = "How to use ESO in applications"
  value = {
    secret_store_ref = var.cluster_secret_store_name
    example_yaml = <<-EOT
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${var.cluster_secret_store_name}
    kind: ClusterSecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: argocd-admin-password
EOT
  }
}
