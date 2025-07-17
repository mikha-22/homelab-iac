# ===================================================================
#  SIMPLIFIED SECRET MANAGER VARIABLES
#  Removed unnecessary complexity for homelab use
# ===================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "homelab-secret-manager"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to Proxmox SSH private key"
  type        = string
  default     = "~/.ssh/proxmox_terraform"
}

variable "secrets" {
  description = "Map of secrets to create"
  type = map(object({
    secret_data = string
    description = optional(string, "Homelab secret")
  }))
  default = {}
}
