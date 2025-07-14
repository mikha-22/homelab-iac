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
  
  # Proxmox API token
  "proxmox-api-token" = {
    secret_data = "terraform@pve!admin=15b3b928-488e-4a60-b471-ccb971aa8bc7"
    description = "Proxmox API token for Terraform provider"
  }
  
  # Proxmox SSH password
  "proxmox-ssh-password" = {
    secret_data = "ikantuna11"
    description = "SSH password for Proxmox root user"
  }
  
  # SSH private key path for Packer
  "ssh-private-key-path" = {
    secret_data = "~/.ssh/proxmox_key"
    description = "Path to SSH private key for Packer/Proxmox access"
  }
  
  # Cloudflare tunnel CNAME
  "tunnel-cname" = {
    secret_data = "eb69efc6-2d0f-424d-a170-53a8c30c65b7.cfargotunnel.com"
    description = "Cloudflare tunnel CNAME for ArgoCD and other services"
  }
  
  # Database credentials for future use
  "postgres-password" = {
    secret_data = "ikantuna11"
    description = "PostgreSQL admin password"
  }
  
  "postgres-user" = {
    secret_data = "postgres"
    description = "PostgreSQL admin username"
  }
  
  # GitHub Actions runner token (for future self-hosted runners)
  "github-runner-token" = {
    secret_data = "REPLACE_WHEN_NEEDED"
    description = "GitHub Actions runner registration token"
  }
}
