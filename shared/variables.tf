variable "network_subnet" {
  description = "Network subnet (e.g., 192.168.1)"
  type        = string
  default     = "192.168.1"
}

variable "domain" {
  description = "Your domain name"
  type        = string
  default     = "milenika.dev"
}

variable "nas_ip" {
  description = "NAS server IP (last octet)"
  type        = number
  default     = 225
}

variable "k3s_master_ip" {
  description = "K3s master IP (last octet)"
  type        = number
  default     = 181
}

variable "k3s_worker_ip" {
  description = "K3s worker IP (last octet)"
  type        = number
  default     = 182
}

variable "gateway_ip" {
  description = "Gateway IP (last octet)"
  type        = number
  default     = 1
}

variable "nas_cores" {
  description = "NAS VM CPU cores"
  type        = number
  default     = 1
}

variable "nas_memory" {
  description = "NAS VM memory (MB)"
  type        = number
  default     = 2048
}

variable "k3s_cores" {
  description = "K3s node CPU cores"
  type        = number
  default     = 6
}

variable "k3s_memory" {
  description = "K3s node memory (MB)"
  type        = number
  default     = 8192
}

variable "base_template_id" {
  description = "Base template VM ID"
  type        = number
  default     = 9999
}

variable "nas_vm_id" {
  description = "NAS VM ID"
  type        = number
  default     = 225
}

variable "k3s_master_vm_id" {
  description = "K3s master VM ID"
  type        = number
  default     = 181
}

variable "k3s_worker_vm_id" {
  description = "K3s worker VM ID"
  type        = number
  default     = 182
}
