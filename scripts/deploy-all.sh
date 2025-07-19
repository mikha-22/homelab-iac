#!/bin/bash
# ===================================================================
#  HOMELAB DEPLOYMENT SCRIPT
#  Deploy the entire homelab infrastructure in the correct order
# ===================================================================

set -e

echo "Starting homelab deployment..."
echo "================================="

# Function to run terraform in a directory
deploy_module() {
    local module_path="$1"
    local module_name="$2"

    echo ""
    echo "Deploying: $module_name"
    echo "Directory: $module_path"
    echo "----------------------------------------"

    cd "$module_path"

    # Initialize and apply
    terraform init
    terraform apply -auto-approve

    # Return to root
    cd - > /dev/null

    echo "$module_name deployed successfully."
}

# Function to run ansible
run_ansible() {
    echo ""
    echo "Running Ansible K3s setup..."
    echo "----------------------------------------"

    cd "05_k3s_ansible_bootstrap"
    ansible-playbook k3s.orchestration.site
    cd - > /dev/null

    echo "K3s cluster deployed successfully."
}

# Check if we're in the right directory
if [[ ! -f "01_gcs_bucket/main.tf" ]]; then
    echo "Error: Please run this script from the homelab-iac root directory."
    exit 1
fi

# Deployment sequence
echo "Starting deployment sequence..."

deploy_module "01_gcs_bucket" "GCS Backend"
deploy_module "02_google_secret_manager" "Secret Manager"
deploy_module "03_nas/01_base_images" "Base Images"
deploy_module "03_nas/02_nas_vm" "NAS Server"
deploy_module "04_bootstrap_vm_nodes/01_download_base_image" "Base Template"
deploy_module "04_bootstrap_vm_nodes/02_template_distribution" "Template Distribution"
deploy_module "04_bootstrap_vm_nodes/03_deploy_vm" "K3s VMs"

run_ansible

deploy_module "06_cloudflare_tunnel" "Cloudflare Tunnel"
deploy_module "07_argocd_bootstrap" "ArgoCD"
deploy_module "08_external_secrets_operator" "External Secrets Operator"

echo ""
echo "HOMELAB DEPLOYMENT COMPLETE"
echo "==============================="
echo ""
echo "Quick Status Check:"
echo "   - K3s Cluster: kubectl get nodes"
echo "   - ArgoCD: https://argocd.milenika.dev"
echo "   - External Secrets: kubectl get clustersecretstore"
echo ""
echo "Useful Commands:"
echo "   - Check status: ./scripts/homelab-status.sh"
echo "   - SSH to master: ssh ubuntu@192.168.1.181"
echo "   - SSH to worker: ssh ubuntu@192.168.1.182"
echo "   - SSH to NAS: ssh mikha@192.168.1.225"
echo ""
echo "Your homelab is ready."
