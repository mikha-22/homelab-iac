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

variable "admin_password" {
  description = "ArgoCD admin password (bcrypt hashed)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "redis_ha_enabled" {
  description = "Enable Redis HA for production"
  type        = bool
  default     = false
}

variable "tunnel_cname" {
  description = "Your Cloudflare tunnel CNAME"
  type        = string
  default     = "0051fa80-d5c3-4095-b44f-a8f6e77f404f.cfargotunnel.com"
}
