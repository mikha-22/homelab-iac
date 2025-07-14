# terraform.tfvars
project_id = "homelab-secret-manager"
region = "us-central1"
k8s_cluster_name = "homelab-k3s"
k8s_namespace = "external-secrets"

secrets = {
  # ArgoCD admin password
  "argocd-admin-password" = {
    secret_data = "admin"
    description = "ArgoCD admin password for homelab"
  }
  
  # MinIO root credentials (from your existing setup)
  "minio-root-user" = {
    secret_data = "admin"
    description = "MinIO root username"
  }
  
  "minio-root-password" = {
    secret_data = "admin123"
    description = "MinIO root password"
  }
  
  # MinIO Hugo user credentials (from your existing setup)
  "minio-hugo-access-key" = {
    secret_data = "hugo-access"
    description = "MinIO user access key for Hugo deployment"
  }
  
  "minio-hugo-secret-key" = {
    secret_data = "hugo-milenika-key"
    description = "MinIO user secret key for Hugo deployment"
  }
  
  # Cloudflare API token for External DNS (your actual token)
  "cloudflare-api-token" = {
    secret_data = "NtdA-v9tJW_qw8V4sFTsRztTK8L6UFbpjLLrwX7b"
    description = "Cloudflare API token for External DNS"
  }
  
  # Cloudflare account/zone info
  "cloudflare-account-id" = {
    secret_data = "590c0c0cf8f069d510a0b3712e2c301c"
    description = "Cloudflare Account ID"
  }
  
  "cloudflare-zone-id" = {
    secret_data = "6894bdff4c224281ce8f72e34a4df11b"
    description = "Cloudflare Zone ID for milenika.dev"
  }
  
  # Grafana admin password
  "grafana-admin-password" = {
    secret_data = "admin"
    description = "Grafana admin password"
  }
}
