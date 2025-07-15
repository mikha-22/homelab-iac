variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "argocd_namespace" {
  description = "Namespace for ArgoCD deployment"
  type        = string
  default     = "argocd"
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD (using your domain)"
  type        = string
  default     = "argocd.milenika.dev"
}

variable "chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "8.1.2"
}

variable "redis_ha_enabled" {
  description = "Enable Redis HA for production"
  type        = bool
  default     = false
}
