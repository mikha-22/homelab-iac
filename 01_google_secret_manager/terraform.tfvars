# terraform.tfvars
project_id = "homelab-secret-manager"
region = "asia-southeast1"
k8s_cluster_name = "homelab-k3s"
k8s_namespace = "external-secrets"

secrets = {
  # ArgoCD admin password
  "argocd-admin-password" = {
    secret_data = "ikantuna11"
    description = "ArgoCD admin password for homelab"
  }
  
  # MinIO root credentials
  "minio-root-user" = {
    secret_data = "admin"
    description = "MinIO root username"
  }
  
  "minio-root-password" = {
    secret_data = "ikantuna11"
    description = "MinIO root password"
  }
  
  # MinIO Hugo user credentials
  "minio-hugo-access-key" = {
    secret_data = "hugo-access"
    description = "MinIO user access key for Hugo deployment"
  }
  
  "minio-hugo-secret-key" = {
    secret_data = "ikantuna11"
    description = "MinIO user secret key for Hugo deployment"
  }
  
  # Cloudflare API token (keep your real token)
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
    secret_data = "ikantuna11"
    description = "Grafana admin password"
  }
}
