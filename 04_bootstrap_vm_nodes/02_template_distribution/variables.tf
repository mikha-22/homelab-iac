# ===================================================================
#  TEMPLATE DISTRIBUTION VARIABLES - SIMPLIFIED
# ===================================================================

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
      node        = "pve1"
      template_id = 9000
    },
    {
      node        = "pve2"
      template_id = 9010
    }
  ]
  
  validation {
    condition = alltrue([
      for target in var.target_nodes :
      target.template_id >= 100 && target.template_id <= 9999
    ])
    error_message = "Template IDs must be between 100 and 9999."
  }
  
  validation {
    condition = length(var.target_nodes) == length(toset([
      for target in var.target_nodes : target.template_id
    ]))
    error_message = "Template IDs must be unique."
  }
}
