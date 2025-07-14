variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"  # Singapore
}

variable "k8s_cluster_name" {
  description = "Name of your K3s cluster (for service account naming)"
  type        = string
  default     = "homelab-k3s"
}

variable "k8s_namespace" {
  description = "Kubernetes namespace where External Secrets Operator will run"
  type        = string
  default     = "external-secrets"
}

variable "secrets" {
  description = "Map of secrets to create in Secret Manager"
  type = map(object({
    secret_data = string
    description = optional(string, "Homelab secret managed by Terraform")
  }))
  default = {}
}
