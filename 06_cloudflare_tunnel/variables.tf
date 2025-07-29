variable "tunnel_name" {
  description = "Cloudflare tunnel name"
  type        = string
  default     = "homelab-k3s-tunnel"
}

variable "cloudflared_replicas" {
  description = "Number of cloudflared pods"
  type        = number
  default     = 2
}

variable "traefik_service_name" {
  description = "Traefik service name"
  type        = string
  default     = "traefik"
}

variable "traefik_namespace" {
  description = "Traefik namespace"
  type        = string
  default     = "kube-system"
}

variable "external_dns_version" {
  description = "External DNS chart version"
  type        = string
  default     = "1.14.3"
}
