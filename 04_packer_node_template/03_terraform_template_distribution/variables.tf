variable "ssh_key_path" {
  description = "Path to SSH private key for Proxmox authentication"
  type        = string
  default     = "~/.ssh/proxmox_key"
}

variable "source_template_id" {
  description = "Source template ID on pve1"
  type        = number
  default     = 9000
}

variable "source_template_name" {
  description = "Name of the source template"
  type        = string
  default     = "ubuntu-2404-k3s-template"
}

variable "target_nodes" {
  description = "Target nodes to copy template to"
  type = list(object({
    node        = string
    template_id = number
  }))
  default = [
    {
      node        = "pve2"
      template_id = 9010
    }
  ]
}
