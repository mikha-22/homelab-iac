output "tunnel" {
  description = "Cloudflare tunnel information"
  value = {
    name     = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name
    id       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
    cname    = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
    domain   = module.shared.domain
    replicas = var.cloudflared_replicas
  }
}

output "kubernetes_components" {
  description = "Deployed Kubernetes components"
  value = {
    cloudflared_namespace   = kubernetes_namespace.cloudflared.metadata[0].name
    external_dns_namespace = kubernetes_namespace.external_dns.metadata[0].name
    external_dns_version   = var.external_dns_version
  }
}

output "service_urls" {
  description = "Available service URLs"
  value = {
    domain = module.shared.domain
    examples = {
      argocd     = "https://argocd.${module.shared.domain}"
      grafana    = "https://grafana.${module.shared.domain}"
      prometheus = "https://prometheus.${module.shared.domain}"
    }
  }
}

output "next_steps" {
  description = "Commands to run next"
  value = {
    deploy_argocd = "cd ../07_argocd_bootstrap && terraform apply"
    test_dns      = "dig @1.1.1.1 test.${module.shared.domain}"
  }
}

output "troubleshooting" {
  description = "Debug commands"
  value = {
    check_cloudflared   = "kubectl get pods -n ${kubernetes_namespace.cloudflared.metadata[0].name}"
    cloudflared_logs    = "kubectl logs -n ${kubernetes_namespace.cloudflared.metadata[0].name} -l app=cloudflared"
    check_external_dns  = "kubectl get pods -n ${kubernetes_namespace.external_dns.metadata[0].name}"
    external_dns_logs   = "kubectl logs -n ${kubernetes_namespace.external_dns.metadata[0].name} -l app.kubernetes.io/name=external-dns"
    test_tunnel_config  = "cloudflared tunnel info ${cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name}"
  }
}
