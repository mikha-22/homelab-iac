# ArgoCD Configuration
argocd_hostname    = "argocd.milenika.dev"
kubeconfig_path    = "~/.kube/config"
argocd_namespace   = "argocd"
chart_version      = "8.1.2"
redis_ha_enabled   = false  # Disable HA to avoid anti-affinity issues in small cluster

# Your Cloudflare tunnel CNAME (UPDATED with latest value)
tunnel_cname = "c6c7a9c0-cde2-4e89-bd87-312697ffd4cc.cfargotunnel.com"

# Optional: Set admin password (bcrypt hashed)
# Generate with: htpasswd -nbBC 10 "" 'your-password' | tr -d ':\n' | sed 's/^[^$]*//'
# admin_password = "$2b$10$..."
