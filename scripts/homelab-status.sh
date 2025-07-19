#!/bin/bash
# Simple homelab health check script

echo "Homelab Status Check"
echo "======================"

# --- Configuration ---
NAS_USER="mikha"
NAS_IP="192.168.1.225"
MASTER_IP="192.168.1.181"
WORKER_IP="192.168.1.182"
DOMAIN="argocd.milenika.dev"

# --- Helper Functions ---
check_ping() {
    local ip=$1
    local name=$2
    ping -c 1 "$ip" >/dev/null 2>&1 && echo "  [OK] $name" || echo "  [FAIL] $name"
}

# Check VMs
echo "VM Status:"
check_ping "$NAS_IP" "NAS Server"
check_ping "$MASTER_IP" "K3s Master"
check_ping "$WORKER_IP" "K3s Worker"

# Check NFS Service via SSH
echo -e "\nStorage:"
if ssh -q -o BatchMode=yes -o ConnectTimeout=5 "${NAS_USER}@${NAS_IP}" "systemctl is-active --quiet nfs-kernel-server"; then
    echo "  [OK] NFS Service"
else
    echo "  [FAIL] NFS Service"
fi

# Check K3s
echo -e "\nKubernetes:"
if kubectl get nodes --no-headers 2>/dev/null | grep -q Ready; then
    echo "  [OK] K3s Cluster"
else
    echo "  [FAIL] K3s Cluster"
fi

# Check Services
echo -e "\nServices:"
kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q Running && echo "  [OK] ArgoCD" || echo "  [FAIL] ArgoCD"
kubectl get pods -n external-secrets --no-headers 2>/dev/null | grep -q Running && echo "  [OK] External Secrets" || echo "  [FAIL] External Secrets"
kubectl get pods -n cloudflared --no-headers 2>/dev/null | grep -q Running && echo "  [OK] Cloudflare Tunnel" || echo "  [FAIL] Cloudflare Tunnel"

# Check DNS
echo -e "\nDNS:"
dig +short "$DOMAIN" >/dev/null 2>&1 && echo "  [OK] External DNS" || echo "  [FAIL] External DNS"

echo -e "\nStatus check complete."
echo "Run 'kubectl get all --all-namespaces' for detailed info."
