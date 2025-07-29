# The ansible k3s installation would allow for kubectl on jumpbox machine
variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "eso_namespace" {
  description = "Namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.15.1"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore resource"
  type        = string
  default     = "gcp-secret-manager"
}

variable "service_account_secret_k8s_name" {
  description = "Name of the Kubernetes secret that will contain the service account key"
  type        = string
  default     = "gcp-secret-manager-sa"
}

variable "enable_ha" {
  description = "Enable high availability mode (2 replicas)"
  type        = bool
  default     = false
}
