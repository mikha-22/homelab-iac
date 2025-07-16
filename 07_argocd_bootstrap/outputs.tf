output "argocd" {
  description = "ArgoCD access information"
  value = {
    url            = "https://${local.argocd_hostname}"
    namespace      = kubernetes_namespace.argocd.metadata[0].name
    chart_version  = var.chart_version
    admin_password = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  }
}

output "ingress" {
  description = "Ingress configuration"
  value = {
    hostname      = local.argocd_hostname
    ingress_class = "traefik"
    tunnel_target = trimspace(data.google_secret_manager_secret_version.tunnel_cname.secret_data)
  }
  sensitive = true
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_eso    = "cd ../08_external_secrets_operator && terraform apply"
    access_ui     = "open https://${local.argocd_hostname}"
    cli_login     = "argocd login ${local.argocd_hostname} --username admin"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    check_pods      = "kubectl get pods -n ${kubernetes_namespace.argocd.metadata[0].name}"
    check_logs      = "kubectl logs -n ${kubernetes_namespace.argocd.metadata[0].name} -l app.kubernetes.io/name=argocd-server"
    port_forward    = "kubectl port-forward svc/argocd-server -n ${kubernetes_namespace.argocd.metadata[0].name} 8080:80"
    check_ingress   = "kubectl get ingress -n ${kubernetes_namespace.argocd.metadata[0].name}"
    test_dns        = "dig @1.1.1.1 ${local.argocd_hostname}"
    test_url        = "curl -I https://${local.argocd_hostname}"
  }
}
