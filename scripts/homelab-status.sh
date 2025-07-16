#!/bin/bash
# Simple homelab health check script

echo "🏠 Homelab Status Check"
echo "======================"

# Check VMs
echo "📱 VM Status:"
ping -c 1 192.168.1.225 >/dev/null 2>&1 && echo "  ✅ NAS Server" || echo "  ❌ NAS Server"
ping -c 1 192.168.1.181 >/dev/null 2>&1 && echo "  ✅ K3s Master" || echo "  ❌ K3s Master"
ping -c 1 192.168.1.182 >/dev/null 2>&1 && echo "  ✅ K3s Worker" || echo "  ❌ K3s Worker"

# Check NFS
echo -e "\n💾 Storage:"
showmount -e 192.168.1.225 >/dev/null 2>&1 && echo "  ✅ NFS Export" || echo "  ❌ NFS Export"

# Check K3s
echo -e "\n☸️  Kubernetes:"
kubectl get nodes --no-headers 2>/dev/null | grep -q Ready && echo "  ✅ K3s Cluster" || echo "  ❌ K3s Cluster"

# Check Services
echo -e "\n🌐 Services:"
kubectl get pods -n argocd --no-headers 2>/dev/null | grep -q Running && echo "  ✅ ArgoCD" || echo "  ❌ ArgoCD"
kubectl get pods -n external-secrets --no-headers 2>/dev/null | grep -q Running && echo "  ✅ External Secrets" || echo "  ❌ External Secrets"
kubectl get pods -n cloudflared --no-headers 2>/dev/null | grep -q Running && echo "  ✅ Cloudflare Tunnel" || echo "  ❌ Cloudflare Tunnel"

# Check DNS
echo -e "\n🌍 DNS:"
dig +short argocd.milenika.dev >/dev/null 2>&1 && echo "  ✅ External DNS" || echo "  ❌ External DNS"

echo -e "\n🎉 Status check complete!"
echo "💡 Run 'kubectl get all --all-namespaces' for detailed info"
