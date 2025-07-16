output "external_secrets" {
  description = "External Secrets Operator information"
  value = {
    namespace           = kubernetes_namespace.external_secrets.metadata[0].name
    cluster_secret_store = var.cluster_secret_store_name
    chart_version       = helm_release.external_secrets.version
    project_id          = module.shared.gcp_project_id
  }
}

output "authentication" {
  description = "GCP authentication configuration"
  value = {
    service_account_secret = kubernetes_secret.gcp_service_account.metadata[0].name
    auth_method           = "service-account-key"
    secret_manager_access = "secretmanager.secretAccessor"
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

output "test_commands" {
  description = "Commands to test ESO functionality"
  value = {
    check_store_status = "kubectl get clustersecretstore ${var.cluster_secret_store_name}"
    describe_store     = "kubectl describe clustersecretstore ${var.cluster_secret_store_name}"
    check_crds         = "kubectl get crd | grep external-secrets"
    test_secret_sync   = "kubectl apply -f - <<EOF\n${replace(local.test_external_secret, "\n", "\\n")}\nEOF"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    check_pods       = "kubectl get pods -n ${kubernetes_namespace.external_secrets.metadata[0].name}"
    controller_logs  = "kubectl logs -n ${kubernetes_namespace.external_secrets.metadata[0].name} -l app.kubernetes.io/name=external-secrets"
    webhook_logs     = "kubectl logs -n ${kubernetes_namespace.external_secrets.metadata[0].name} -l app.kubernetes.io/name=external-secrets-webhook"
    check_auth       = "kubectl get clustersecretstore ${var.cluster_secret_store_name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")]}'"
  }
}

locals {
  test_external_secret = <<-EOT
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: ${var.cluster_secret_store_name}
    kind: ClusterSecretStore
  target:
    name: test-gcp-secret
    creationPolicy: Owner
  data:
  - secretKey: password
    remoteRef:
      key: argocd-admin-password
EOT
}
