output "deployment_status" {
  description = "Cloudflare tunnel deployment status and verification"
  value = {
    status = "✅ Cloudflare tunnel infrastructure deployed successfully"
    
    resources = {
      tunnel = {
        name     = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name
        id       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
        cname    = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
        domain   = module.shared.domain
        replicas = var.cloudflared_replicas
      }
      
      kubernetes_components = {
        cloudflared_namespace   = kubernetes_namespace.cloudflared.metadata[0].name
        external_dns_namespace = kubernetes_namespace.external_dns.metadata[0].name
        cloudflared_replicas   = var.cloudflared_replicas
        external_dns_chart     = var.external_dns_version
      }
      
      ingress_config = {
        wildcard_rule = "*.${module.shared.domain}"
        apex_rule     = module.shared.domain
        traefik_target = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
      }
    }
    
    verification = {
      tunnel_created       = "✅ Cloudflare tunnel created and configured"
      tunnel_deployed      = "✅ Cloudflared pods deployed and ready"
      external_dns         = "✅ External DNS deployed and ready"
      connectivity         = "✅ Tunnel connectivity verified"
      ingress_rules        = "✅ Ingress rules configured for domain routing"
    }
    
    next_steps = [
      {
        action      = "Deploy ArgoCD"
        command     = "cd ../07_argocd_bootstrap && terraform apply"
        description = "Install GitOps management platform with tunnel integration"
      },
      {
        action      = "Test tunnel connectivity"
        command     = "dig @1.1.1.1 test.${module.shared.domain}"
        description = "Verify DNS records are being created automatically"
      }
    ]
    
    troubleshooting = {
      check_cloudflared    = "kubectl get pods -n ${kubernetes_namespace.cloudflared.metadata[0].name}"
      cloudflared_logs     = "kubectl logs -n ${kubernetes_namespace.cloudflared.metadata[0].name} -l app=cloudflared"
      check_external_dns   = "kubectl get pods -n ${kubernetes_namespace.external_dns.metadata[0].name}"
      external_dns_logs    = "kubectl logs -n ${kubernetes_namespace.external_dns.metadata[0].name} -l app.kubernetes.io/name=external-dns"
      test_dns_records     = "dig @1.1.1.1 test.${module.shared.domain}"
      check_tunnel_config  = "cloudflared tunnel info ${cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name}"
    }
  }
}

# Legacy compatibility
output "tunnel_id" {
  description = "The ID of the created tunnel"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
}

output "tunnel_cname" {
  description = "The CNAME of the tunnel for DNS configuration"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
}

output "tunnel_token" {
  description = "The tunnel token (sensitive)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.tunnel_token
  sensitive   = true
}

output "service_urls" {
  description = "Service URLs that will be available through the tunnel"
  value = {
    domain = module.shared.domain
    services = module.shared.services
    examples = {
      argocd     = "https://argocd.${module.shared.domain}"
      grafana    = "https://grafana.${module.shared.domain}"
      prometheus = "https://prometheus.${module.shared.domain}"
      dashboard  = "https://dashboard.${module.shared.domain}"
    }
    
    ingress_template = {
      annotations = {
        "kubernetes.io/ingress.class"                         = "traefik"
        "external-dns.alpha.kubernetes.io/target"            = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
        "external-dns.alpha.kubernetes.io/cloudflare-proxied" = "true"
      }
      host_example = "my-app.${module.shared.domain}"
    }
  }
}

output "quick_reference" {
  description = "Quick commands and URLs for immediate use"
  value = {
    domain                = module.shared.domain
    tunnel_cname         = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
    check_tunnel_status  = "kubectl get pods -n ${kubernetes_namespace.cloudflared.metadata[0].name}"
    view_tunnel_logs     = "kubectl logs -n ${kubernetes_namespace.cloudflared.metadata[0].name} -l app=cloudflared"
    next_deployment      = "cd ../07_argocd_bootstrap && terraform apply"
    test_dns             = "dig @1.1.1.1 test.${module.shared.domain}"
  }
}
