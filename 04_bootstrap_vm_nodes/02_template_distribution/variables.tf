variable "ssh_key_path" {
  description = "Path to SSH private key for Proxmox authentication"
  type        = string
  default     = "~/.ssh/proxmox_terraform"  # Updated to match our new key
}

variable "source_template_id" {
  description = "Source template ID on pve1 (the base template created in step 1)"
  type        = number
  default     = 9999  # Base template
}

variable "source_template_name" {
  description = "Name of the source template"
  type        = string
  default     = "ubuntu-2404-cloud-base"
}

variable "target_nodes" {
  description = "Target nodes to copy template to with their template IDs"
  type = list(object({
    node        = string
    template_id = number
  }))
  default = [
    {
      node        = "pve1"  # Create template 9000 on pve1 for master
      template_id = 9000
    },
    {
      node        = "pve2"  # Create template 9010 on pve2 for worker
      template_id = 9010
    }
  ]
}

# Add missing local for SSH options
locals {
  ssh_opts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${var.ssh_key_path}"
}
