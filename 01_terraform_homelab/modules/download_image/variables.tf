variable "url" {
  description = "The URL of the cloud image to download."
  type        = string
}

variable "datastore_id" {
  description = "The Proxmox datastore ID to download the file to."
  type        = string
  default     = "local"
}

variable "node_name" {
  description = "The Proxmox node where the file will be stored."
  type        = string
}

variable "content_type" {
  description = "The content type for the downloaded file (e.g., 'iso', 'vztmpl')."
  type        = string
  default     = "iso"
}

variable "file_name" {
  description = "The desired file name. If empty, it will be derived from the URL."
  type        = string
  default     = ""
}
