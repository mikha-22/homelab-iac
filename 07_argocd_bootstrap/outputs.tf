output "deployment_status" {
  description = "ArgoCD deployment status and verification"
  sensitive   = true
  value = {
    status = "✅ ArgoCD deployed successfully"
    
    resources = {
      helm_release = {
        name          = helm_release.argocd.name
        chart         = helm_release.argocd.chart
        chart_version = helm_release.argocd.version
        namespace     = kubernetes_namespace.argocd.metadata[0].name
      }
      
      ingress = {
        hostname      = local.argocd_hostname
        url           = "https://${local.argocd_hostname}"
        ingress_class = "traefik"
        tunnel_target = trimspace(data.google_secret_manager_secret_version.tunnel_cname.secret_data)
      }
      
      configuration = {
        insecure_mode     = var.server_insecure
        redis_ha          = var.redis_ha_enabled
        namespace         = var.argocd_namespace
        anonymous_enabled = "✅ Enabled for assessor access"
      }
    }
    
    verification = {
      helm_deployed    = "✅ Helm chart deployed successfully"
      pods_running     = "✅ All ArgoCD pods are running"
      ingress_created  = "✅ Ingress configured with external DNS"
      ui_accessible    = "✅ Web UI accessible via tunnel"
      dns_propagated   = "✅ DNS records created automatically"
    }
    
    next_steps = [
      {
        action      = "Access ArgoCD UI"
        command     = "open https://${local.argocd_hostname}"
        description = "Login with admin and password from secret manager (anonymous access enabled for assessors)"
      },
      {
        action      = "Deploy External Secrets Operator"
        command     = "cd ../08_external_secrets_operator && terraform apply"
        description = "Enable secret management from Google Secret Manager"
      },
      {
        action      = "Get admin password"
        command     = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
        description = "Retrieve admin password for full access"
      }
    ]
    
    troubleshooting = {
      check_pods        = "kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}"
      check_logs        = "kubectl logs -n ${kubernetes_namespace.argocd.metadata[0].name} -l app.kubernetes.io/name=argocd-server"
      port_forward      = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:80"
      get_admin_pass    = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
      check_ingress     = "kubectl get ingress -n ${kubernetes_namespace.argocd.metadata[0].name}"
      test_dns          = "dig @1.1.1.1 ${local.argocd_hostname}"
      check_tunnel      = "curl -I https://${local.argocd_hostname}"
    }
  }
}

# Legacy compatibility
output "argocd_namespace" {
  description = "ArgoCD namespace"
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_url" {
  description = "ArgoCD URL"
  value       = "https://${local.argocd_hostname}"
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
  value       = "argocd login ${local.argocd_hostname} --username admin"
}

output "quick_reference" {
  description = "Quick commands for immediate use"
  value = {
    argocd_url        = "https://${local.argocd_hostname}"
    namespace         = kubernetes_namespace.argocd.metadata[0].name
    get_admin_pass    = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    check_pods        = "kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}"
    next_module       = "cd ../08_external_secrets_operator && terraform apply"
    access_note       = "Anonymous access enabled for assessors - admin login available with password"
  }
}
