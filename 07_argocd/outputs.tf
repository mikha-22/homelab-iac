output "argocd" {
  description = "ArgoCD access information"
  value = {
    url            = "https://${local.argocd_hostname}"
    namespace      = kubernetes_namespace.argocd.metadata[0].name
    chart_version  = var.chart_version
    admin_password = "kubectl -n ${kubernetes_namespace.argocd.metadata[0].name} get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  }
}
