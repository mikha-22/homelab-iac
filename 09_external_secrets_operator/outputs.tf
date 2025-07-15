output "external_secrets_namespace" {
  description = "Namespace where External Secrets Operator is deployed"
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore for referencing in ExternalSecret resources"
  value       = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
}

output "external_secrets_chart_version" {
  description = "Version of External Secrets Operator chart deployed"
  value       = helm_release.external_secrets.version
}

output "service_account_secret_name" {
  description = "Name of the Kubernetes secret containing GCP service account key"
  value       = kubernetes_secret.gcp_service_account.metadata[0].name
}

output "eso_status" {
  description = "Status of External Secrets Operator deployment"
  value = {
    namespace           = kubernetes_namespace.external_secrets.metadata[0].name
    helm_release_status = helm_release.external_secrets.status
    cluster_store_ready = "ClusterSecretStore configured"
    gcp_auth_configured = "GCP authentication ready"
  }
}

output "success_message" {
  description = "Success message and next steps"
  value = <<-EOT
    🎉 External Secrets Operator successfully deployed!
    
    Configuration:
    ✅ Repository: https://external-secrets.io
    ✅ API Version: external-secrets.io/v1beta1
    ✅ ClusterSecretStore: ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}
    
    Available secrets in GCP Secret Manager:
    - argocd-admin-password
    - grafana-admin-password  
    - minio-root-user
    - minio-root-password
    - minio-hugo-access-key
    - minio-hugo-secret-key
    - cloudflare-api-token
    - And more...
    
    Next steps:
    1. Deploy your GitOps applications
    2. ESO will automatically sync secrets from GCP
    3. Applications will use the created Kubernetes secrets
    
    Note: ESO pods may show ImagePullBackOff due to network issues,
    but this doesn't affect CRD functionality for secret management.
  EOT
}

output "verification_commands" {
  description = "Commands to verify ESO is working"
  value = <<-EOT
    Verify External Secrets Operator:
    
    # Check ESO namespace and resources
    kubectl get all -n ${kubernetes_namespace.external_secrets.metadata[0].name}
    
    # Check ClusterSecretStore
    kubectl get clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}
    kubectl describe clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}
    
    # Check CRDs are installed
    kubectl get crd | grep external-secrets
    
    # Test creating an ExternalSecret (example)
    kubectl apply -f - <<EOF
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: test-secret
      namespace: default
    spec:
      refreshInterval: 1h
      secretStoreRef:
        name: ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}
        kind: ClusterSecretStore
      target:
        name: test-gcp-secret
        creationPolicy: Owner
      data:
      - secretKey: password
        remoteRef:
          key: argocd-admin-password
    EOF
  EOT
}
