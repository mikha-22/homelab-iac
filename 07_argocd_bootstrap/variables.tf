# ===================================================================
#  ARGOCD VARIABLES - UPDATED WITH SHARED CONFIG
#  Domain name now comes from shared configuration
# ===================================================================

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
  
  validation {
    condition     = can(regex("^[/~].*", var.kubeconfig_path))
    error_message = "Kubeconfig path must be an absolute path or start with ~."
  }
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.argocd_namespace))
    error_message = "Namespace must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.8"
  
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.chart_version))
    error_message = "Chart version must be in semantic version format (e.g., 7.7.8)."
  }
}

variable "argocd_hostname" {
  description = "ArgoCD hostname (defaults to argocd.domain from shared config)"
  type        = string
  default     = ""
  
  validation {
    condition = var.argocd_hostname == "" || can(regex("^[a-z0-9.-]+$", var.argocd_hostname))
    error_message = "Hostname must contain only lowercase letters, numbers, dots, and hyphens."
  }
}

variable "server_insecure" {
  description = "Run ArgoCD server in insecure mode (required for Cloudflare tunnel)"
  type        = bool
  default     = true
}

variable "redis_ha_enabled" {
  description = "Enable Redis HA (recommended for production)"
  type        = bool
  default     = false
}

variable "enable_metrics" {
  description = "Enable Prometheus metrics collection"
  type        = bool
  default     = true
}

variable "enable_notifications" {
  description = "Enable ArgoCD notifications controller"
  type        = bool
  default     = true
}

variable "enable_applicationset" {
  description = "Enable ArgoCD ApplicationSet controller"
  type        = bool
  default     = true
}

variable "resource_limits" {
  description = "Resource limits for ArgoCD components"
  type = object({
    server = optional(object({
      cpu_limit      = optional(string, "500m")
      memory_limit   = optional(string, "512Mi")
      cpu_request    = optional(string, "250m")
      memory_request = optional(string, "256Mi")
    }), {})
    controller = optional(object({
      cpu_limit      = optional(string, "1000m")
      memory_limit   = optional(string, "1Gi")
      cpu_request    = optional(string, "500m")
      memory_request = optional(string, "512Mi")
    }), {})
    repo_server = optional(object({
      cpu_limit      = optional(string, "500m")
      memory_limit   = optional(string, "512Mi")
      cpu_request    = optional(string, "250m")
      memory_request = optional(string, "256Mi")
    }), {})
  })
  default = {}
}

variable "additional_annotations" {
  description = "Additional annotations for ArgoCD ingress"
  type        = map(string)
  default     = {}
}

variable "additional_labels" {
  description = "Additional labels for ArgoCD resources"
  type        = map(string)
  default     = {}
}

# --- COMPUTED VALUES ---
locals {
  # Final resource configuration
  final_resource_limits = {
    server = merge(
      {
        cpu_limit      = "500m"
        memory_limit   = "512Mi"
        cpu_request    = "250m"
        memory_request = "256Mi"
      },
      var.resource_limits.server
    )
    controller = merge(
      {
        cpu_limit      = "1000m"
        memory_limit   = "1Gi"
        cpu_request    = "500m"
        memory_request = "512Mi"
      },
      var.resource_limits.controller
    )
    repo_server = merge(
      {
        cpu_limit      = "500m"
        memory_limit   = "512Mi"
        cpu_request    = "250m"
        memory_request = "256Mi"
      },
      var.resource_limits.repo_server
    )
  }
  
  # ArgoCD configuration
  argocd_config = {
    namespace        = var.argocd_namespace
    chart_version    = var.chart_version
    server_insecure  = var.server_insecure
    redis_ha         = var.redis_ha_enabled
    metrics_enabled  = var.enable_metrics
  }
}
