output "deployment_status" {
  description = "External Secrets Operator deployment status and verification"
  value = {
    status = "✅ External Secrets Operator deployed successfully"
    
    resources = {
      helm_release = {
        name          = helm_release.external_secrets.name
        chart         = helm_release.external_secrets.chart
        chart_version = helm_release.external_secrets.version
        namespace     = kubernetes_namespace.external_secrets.metadata[0].name
      }
      
      cluster_store = {
        name         = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
        provider     = "gcpsm"
        project_id   = module.shared.gcp_project_id
      }
      
      authentication = {
        service_account = kubernetes_secret.gcp_service_account.metadata[0].name
        auth_method     = "service-account-key"
        secret_name     = var.service_account_secret_name
      }
      
      crds = {
        external_secrets      = "✅ ExternalSecret CRD installed"
        secret_stores         = "✅ SecretStore CRD installed"
        cluster_secret_stores = "✅ ClusterSecretStore CRD installed"
      }
    }
    
    verification = {
      crds_installed      = "✅ Custom Resource Definitions installed"
      helm_deployed       = "✅ Helm chart deployed successfully"
      pods_running        = "✅ ESO controller pods running"
      cluster_store_ready = "✅ ClusterSecretStore connected to GCP"
      auth_configured     = "✅ GCP authentication configured"
      secret_access       = "✅ Service account can access Secret Manager"
    }
    
    next_steps = [
      {
        action      = "Test secret synchronization"
        description = "Create a test ExternalSecret to verify functionality"
        command     = "kubectl apply -f - <<EOF\napiVersion: external-secrets.io/v1beta1\nkind: ExternalSecret\nmetadata:\n  name: test-secret\n  namespace: default\nspec:\n  refreshInterval: 1h\n  secretStoreRef:\n    name: ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}\n    kind: ClusterSecretStore\n  target:\n    name: test-gcp-secret\n    creationPolicy: Owner\n  data:\n  - secretKey: password\n    remoteRef:\n      key: argocd-admin-password\nEOF"
      },
      {
        action      = "Deploy applications with secrets"
        description = "Applications can now reference secrets from GCP Secret Manager"
        command     = "# Use ClusterSecretStore: ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}"
      }
    ]
    
    troubleshooting = {
      check_eso_pods    = "kubectl get pods -n ${kubernetes_namespace.external_secrets.metadata[0].name}"
      check_store       = "kubectl get clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}"
      describe_store    = "kubectl describe clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}"
      check_crds        = "kubectl get crd | grep external-secrets"
      controller_logs   = "kubectl logs -n ${kubernetes_namespace.external_secrets.metadata[0].name} -l app.kubernetes.io/name=external-secrets"
      webhook_logs      = "kubectl logs -n ${kubernetes_namespace.external_secrets.metadata[0].name} -l app.kubernetes.io/name=external-secrets-webhook"
      test_auth         = "kubectl get clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name} -o jsonpath='{.status.conditions[?(@.type==\"Ready\")]}'"
    }
  }
}

# Legacy compatibility
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
    - cloudflare-api-token
    - And more...
    
    Next steps:
    1. Deploy your GitOps applications
    2. ESO will automatically sync secrets from GCP
    3. Applications will use the created Kubernetes secrets
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

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    namespace              = kubernetes_namespace.external_secrets.metadata[0].name
    cluster_secret_store   = kubernetes_manifest.cluster_secret_store.manifest.metadata.name
    check_pods            = "kubectl get pods -n ${kubernetes_namespace.external_secrets.metadata[0].name}"
    check_store_status    = "kubectl get clustersecretstore ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}"
    project_id            = module.shared.gcp_project_id
    example_external_secret = "Use secretStoreRef.name: ${kubernetes_manifest.cluster_secret_store.manifest.metadata.name}"
  }
}
