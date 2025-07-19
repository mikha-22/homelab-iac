# ===================================================================
#  CLOUDFLARE TUNNEL OUTPUTS - ESSENTIAL ONLY
# ===================================================================

output "tunnel" {
  description = "Cloudflare tunnel information"
  value = {
    name   = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.name
    id     = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.id
    cname  = cloudflare_zero_trust_tunnel_cloudflared.k3s_tunnel.cname
    domain = module.shared.domain
  }
}

output "service_urls" {
  description = "Available service URLs"
  value = {
    domain = module.shared.domain
    argocd = "https://argocd.${module.shared.domain}"
  }
}
