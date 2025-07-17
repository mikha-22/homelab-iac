# Homelab Infrastructure as Code

Deploy a K3s homelab with GitOps using Terraform and Ansible.

## What This Builds

- **2-node Proxmox cluster** with shared NFS storage
- **K3s Kubernetes** cluster (1 master, 1 worker)
- **ArgoCD** for GitOps deployments
- **External Secrets Operator** syncing from Google Secret Manager
- **Cloudflare tunnel** for secure external access
- **No Packer needed** - direct template cloning

## Quick Deploy

```bash
# 1. Set up the secrets in 02_google_secret_manager/terraform.tfvars
# 2. Run the deploy script
./scripts/deploy-all.sh
```

## Manual Deploy (if script fails)

```bash
# Deploy in this exact order:
cd 01_gcs_bucket && terraform init && terraform apply
cd ../02_google_secret_manager && terraform init && terraform apply
cd ../03_nas/01_base_images && terraform init && terraform apply
cd ../02_nas_vm && terraform init && terraform apply
cd ../../../04_bootstrap_vm_nodes/01_download_base_image && terraform init && terraform apply
cd ../02_template_distribution && terraform init && terraform apply
cd ../03_deploy_vm && terraform init && terraform apply
cd ../../05_k3s_ansible_bootstrap && ansible-playbook k3s.orchestration.site
cd ../06_cloudflare_tunnel && terraform init && terraform apply
cd ../07_argocd_bootstrap && terraform init && terraform apply
cd ../08_external_secrets_operator && terraform init && terraform apply
```

## Configuration

### Network (edit `shared/variables.tf` if needed)
- **Subnet**: 192.168.1.0/24
- **NAS**: 192.168.1.225
- **K3s Master**: 192.168.1.181
- **K3s Worker**: 192.168.1.182
- **Domain**: milenika.dev

### Resources
- **NAS**: 1 core, 2GB RAM, 50GB disk
- **Master**: 6 cores, 8GB RAM, 20GB disk  
- **Worker**: 6 cores, 8GB RAM, 20GB disk

## Prerequisites

1. **Proxmox cluster**: 2 nodes (pve1, pve2)
2. **Google Cloud project** with Secret Manager
3. **Cloudflare account** with domain
4. **Local tools**: terraform, kubectl, ansible

### Required Secrets

Create `02_google_secret_manager/terraform.tfvars`:

```hcl
project_id = "your-gcp-project"
secrets = {
  "proxmox-api-token" = {
    secret_data = "your-proxmox-token"
  }
  "proxmox-ssh-private-key" = {
    secret_data = "your-ssh-private-key"  
  }
  "cloudflare-api-token" = {
    secret_data = "your-cloudflare-token"
  }
  "cloudflare-account-id" = {
    secret_data = "your-cloudflare-account-id"
  }
  "argocd-admin-password" = {
    secret_data = "your-argocd-password"
  }
  # ... other secrets
}
```

## After Deployment

### Access Services
- **ArgoCD**: https://argocd.milenika.dev
- **K3s cluster**: `kubectl get nodes`
- **Check status**: `./scripts/homelab-status.sh`

### SSH Access
```bash
ssh ubuntu@192.168.1.181  # K3s master
ssh ubuntu@192.168.1.182  # K3s worker  
ssh mikha@192.168.1.225   # NAS server
```

### Test External Secrets
```bash
kubectl get clustersecretstore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: test-secret
spec:
  secretStoreRef:
    name: gcp-secret-manager
    kind: ClusterSecretStore
  target:
    name: test-gcp-secret
  data:
  - secretKey: password
    remoteRef:
      key: argocd-admin-password
EOF
```

## Troubleshooting

```bash
# Check everything
./scripts/homelab-status.sh

# Individual components
kubectl get nodes
kubectl get pods --all-namespaces
kubectl get clustersecretstore
terraform state list

# Logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
kubectl logs -n external-secrets -l app.kubernetes.io/name=external-secrets
```

## Customization

Edit `shared/variables.tf` for:
- Different network subnet
- Custom VM resources  
- Your domain name
- Environment sizing (minimal/homelab/development)
