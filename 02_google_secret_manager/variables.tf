# ===================================================================
#  SIMPLIFIED SECRET MANAGER VARIABLES
#  Removed unnecessary complexity for homelab use
# ===================================================================

variable "project_id" { # declares a variable named project_id, description for this variable, the data type, and then
                        # the default value if its not overridden  
  description = "GCP Project ID"
  type        = string
  default     = "homelab-secret-manager"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-southeast1"
}

variable "ssh_public_key_path" { # this variable contains the path for the key, later will be processed in main.tf
  description = "Path to SSH public key for VM access"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "proxmox_ssh_private_key_path" {
  description = "Path to Proxmox SSH private key"
  type        = string
  default     = "~/.ssh/proxmox_terraform"
}

# For the variable below, type is not a string, it's a specific object with certain rules to be populated with the real
# sensitive values.
#
# map(object({secret_data = string
# description = optional(string, "Homelab secret")}))
# 
# The newline after secret_data = string is important because unlike json, terraform uses enter or newline as a delimiter
# The description contains an optional function, which makes it not mandatory to be populated, the default value is 
# "Homelab secret"
#
# Check terraform.tfvars for actual value, for approximation it will look like this =
#
# "admin_password" = {   ## which is the map name
#   secret_data = "admin123" ## which is the key-value
#   description = "password for the admin account" ## this one is not mandatory, if left blank it will use "Homelab secret"
# }                                                   as the value.
#  
# And if not populated, the default value of this map is empty

variable "secrets" { 
  description = "Map of secrets to create"
  type = map(object({
    secret_data = string
    description = optional(string, "Homelab secret")
  }))
  default = {}
}
