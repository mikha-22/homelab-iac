variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
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

variable "ssh_public_key_path" {
  description = "Path to the public SSH key file for VM user access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to the Proxmox SSH private key file"
  type        = string
  default     = "~/.ssh/proxmox_terraform"
}
