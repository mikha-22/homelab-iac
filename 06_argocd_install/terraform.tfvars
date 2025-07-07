# ArgoCD Configuration
argocd_hostname    = "argocd.milenika.dev"
kubeconfig_path    = "~/.kube/config"
argocd_namespace   = "argocd"
chart_version      = "8.1.2"
redis_ha_enabled   = true

# Your Cloudflare tunnel CNAME (from your existing setup)
tunnel_cname = "e3eb2656-ba08-487e-86df-5788a51be54d.cfargotunnel.com"

# Optional: Set admin password (bcrypt hashed)
# Generate with: htpasswd -nbBC 10 "" 'your-password' | tr -d ':\n' | sed 's/^[^$]*//'
# admin_password = "$2b$10$..."
