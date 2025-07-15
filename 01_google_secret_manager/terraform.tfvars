# 01_google_secret_manager/terraform.tfvars
# Complete secret configuration for GitOps deployment

# Your GCP Project ID
project_id = "homelab-secret-manager"

# GCP Region
region = "asia-southeast1"

# Your cluster name
k8s_cluster_name = "homelab-k3s"

# Namespace where External Secrets Operator will be deployed
k8s_namespace = "external-secrets"

# Path to your public SSH key for general VM access
ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Path to your public SSH key for Packer automation
packer_public_key_path = "~/.ssh/id_rsa.pub"

# Complete secrets configuration for GitOps
secrets = {
  # === INFRASTRUCTURE SECRETS ===
  
  # Proxmox API credentials
  "proxmox-api-token" = {
    secret_data = "terraform@pve!admin=15b3b928-488e-4a60-b471-ccb971aa8bc7"
    description = "Proxmox API token for Terraform automation"
  }
  
  "proxmox-ssh-password" = {
    secret_data = "your-proxmox-root-password"
    description = "Proxmox root SSH password"
  }
  
  # Cloudflare credentials
  "cloudflare-api-token" = {
    secret_data = "your-cloudflare-api-token"
    description = "Cloudflare API token for External DNS and tunnel management"
  }
  
  "cloudflare-account-id" = {
    secret_data = "your-cloudflare-account-id"
    description = "Cloudflare account ID for tunnel configuration"
  }
  
  "tunnel-cname" = {
    secret_data = "a62a3256-8662-4884-8f28-607bfa7526a9.cfargotunnel.com"
    description = "Cloudflare tunnel CNAME for ingress configuration"
  }
  
  # === APPLICATION SECRETS ===
  
  # ArgoCD admin credentials
  "argocd-admin-password" = {
    secret_data = "your-secure-argocd-password"
    description = "ArgoCD admin password for GitOps dashboard access"
  }
  
  # Grafana admin credentials
  "grafana-admin-password" = {
    secret_data = "your-secure-grafana-password"
    description = "Grafana admin password for monitoring dashboard"
  }
  
  # MinIO credentials
  "minio-root-user" = {
    secret_data = "admin"
    description = "MinIO root username for object storage"
  }
  
  "minio-root-password" = {
    secret_data = "your-secure-minio-password"
    description = "MinIO root password for object storage admin access"
  }
  
  "minio-hugo-access-key" = {
    secret_data = "hugo-access"
    description = "MinIO access key for Hugo static site deployment"
  }
  
  "minio-hugo-secret-key" = {
    secret_data = "your-secure-hugo-secret-key"
    description = "MinIO secret key for Hugo static site deployment"
  }
  
  # === OPTIONAL SECRETS FOR FUTURE USE ===
  
  # Database credentials (for future database deployments)
  "postgres-password" = {
    secret_data = "your-secure-db-password"
    description = "PostgreSQL admin password"
  }
  
  "mysql-root-password" = {
    secret_data = "your-secure-mysql-password"
    description = "MySQL root password"
  }
  
  # GitHub Actions runner token (if using self-hosted runners)
  "github-runner-token" = {
    secret_data = "your-github-runner-token"
    description = "GitHub Actions runner registration token"
  }
  
  # Email/SMTP credentials (for notifications)
  "smtp-username" = {
    secret_data = "your-smtp-username"
    description = "SMTP username for email notifications"
  }
  
  "smtp-password" = {
    secret_data = "your-smtp-password"
    description = "SMTP password for email notifications"
  }
  
  # SSL certificate secrets (if using custom certs)
  "tls-cert" = {
    secret_data = "your-tls-certificate"
    description = "Custom TLS certificate for applications"
  }
  
  "tls-key" = {
    secret_data = "your-tls-private-key"
    description = "Custom TLS private key for applications"
  }
  
  # Backup storage credentials
  "backup-s3-access-key" = {
    secret_data = "your-backup-access-key"
    description = "S3 access key for backup storage"
  }
  
  "backup-s3-secret-key" = {
    secret_data = "your-backup-secret-key"
    description = "S3 secret key for backup storage"
  }

  "external-secrets-service-account-key" = {
    secret_data = "PLACEHOLDER-WILL-BE-UPDATED-AFTER-KEY-CREATION"
    description = "Service account key for External Secrets Operator to access GCP Secret Manager"
  }
}
