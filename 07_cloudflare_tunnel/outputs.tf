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

output "setup_complete" {
  description = "Complete setup summary"
  value = {
    tunnel_created    = "✅ Tunnel: ${cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name}"
    external_dns      = "✅ ExternalDNS: Deployed in ${kubernetes_namespace.external_dns.metadata[0].name} namespace"
    cloudflared       = "✅ Cloudflared: 2 replicas running in ${kubernetes_namespace.cloudflared.metadata[0].name} namespace"
    next_steps        = "Deploy your apps with ingress annotations!"
  }
}
