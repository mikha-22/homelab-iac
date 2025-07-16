# ===================================================================
#  CLOUDFLARE TUNNEL VARIABLES - SIMPLIFIED VALIDATION
# ===================================================================

variable "tunnel_name" {
  description = "Name for your Cloudflare Tunnel"
  type        = string
  default     = "homelab-k3s-tunnel"
}

variable "traefik_service_name" {
  description = "Traefik service name in Kubernetes"
  type        = string
  default     = "traefik"
}

variable "traefik_namespace" {
  description = "Kubernetes namespace where Traefik is deployed"
  type        = string
  default     = "kube-system"
}

variable "cloudflared_replicas" {
  description = "Number of cloudflared replicas to run"
  type        = number
  default     = 2
  
  validation {
    condition     = var.cloudflared_replicas >= 1 && var.cloudflared_replicas <= 10
    error_message = "Cloudflared replicas must be between 1 and 10."
  }
}

variable "external_dns_version" {
  description = "External DNS Helm chart version"
  type        = string
  default     = "1.14.3"
}

variable "enable_tunnel_metrics" {
  description = "Enable metrics collection for tunnel monitoring"
  type        = bool
  default     = true
}

variable "tunnel_log_level" {
  description = "Log level for cloudflared (debug, info, warn, error)"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.tunnel_log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "enable_debug_logging" {
  description = "Enable debug logging for troubleshooting"
  type        = bool
  default     = false
}

variable "enable_advanced_routing" {
  description = "Enable advanced routing rules (for future use)"
  type        = bool
  default     = false
}

variable "resource_limits" {
  description = "Resource limits for tunnel components"
  type = object({
    cloudflared = optional(object({
      cpu_limit      = optional(string, "100m")
      memory_limit   = optional(string, "128Mi")
      cpu_request    = optional(string, "50m")
      memory_request = optional(string, "64Mi")
    }), {})
    external_dns = optional(object({
      cpu_limit      = optional(string, "100m")
      memory_limit   = optional(string, "128Mi")
      cpu_request    = optional(string, "50m")
      memory_request = optional(string, "64Mi")
    }), {})
  })
  default = {}
}

# --- COMPUTED VALUES ---
locals {
  tunnel_config = {
    name         = var.tunnel_name
    replicas     = var.cloudflared_replicas
    log_level    = var.tunnel_log_level
    enable_metrics = var.enable_tunnel_metrics
  }
  
  traefik_config = {
    service_name = var.traefik_service_name
    namespace    = var.traefik_namespace
    service_url  = "http://${var.traefik_service_name}.${var.traefik_namespace}.svc.cluster.local:80"
  }
  
  external_dns_config = {
    chart_version = var.external_dns_version
    txt_owner_id  = "homelab-k3s"
    policy        = "sync"
    interval      = "1m"
    log_level     = "info"
  }
}
