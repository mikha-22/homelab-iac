# ===================================================================
#  ARGOCD VARIABLES - SIMPLIFIED
# ===================================================================

variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "7.7.8"
}

variable "argocd_hostname" {
  description = "ArgoCD hostname (defaults to argocd.domain from shared config)"
  type        = string
  default     = ""
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
