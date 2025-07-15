# All cloudflare_* variables have been removed.
# Only non-sensitive variables remain.

variable "tunnel_name" {
  type        = string
  description = "A name for your Cloudflare Tunnel."
  default     = "homelab-k3s-tunnel"
}

variable "domain_name" {
  type        = string
  description = "Your domain name"
  default     = "milenika.dev"
}

variable "traefik_service_name" {
  type        = string
  description = "Traefik service name"
  default     = "traefik"
}

variable "traefik_namespace" {
  type        = string
  description = "Traefik namespace"
  default     = "kube-system"
}
