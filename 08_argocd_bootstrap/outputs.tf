output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://${var.argocd_hostname}"
}

output "admin_password_command" {
  description = "Command to get initial admin password"
  value       = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "port_forward_command" {
  description = "Command for local port forwarding (for testing)"
  value       = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:80"
}

output "cli_login_command" {
  description = "ArgoCD CLI login command"
  value       = "argocd login ${var.argocd_hostname} --username admin"
}

output "deployment_status" {
  description = "Deployment summary"
  value = {
    argocd_deployed    = "✅ ArgoCD deployed to ${kubernetes_namespace.argocd.metadata[0].name} namespace"
    chart_version      = var.chart_version
    hostname          = var.argocd_hostname
    insecure_mode     = "✅ Configured for Cloudflare TLS termination"
    ingress_created   = "✅ Ingress configured with ExternalDNS"
    redis_ha          = var.redis_ha_enabled ? "✅ Redis HA enabled" : "❌ Redis HA disabled"
  }
}
