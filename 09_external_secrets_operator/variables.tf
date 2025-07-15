variable "kubeconfig_path" {
  description = "Path to kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

variable "gcp_project_id" {
  description = "GCP Project ID where secrets are stored"
  type        = string
  default     = "homelab-secret-manager"
}

variable "eso_namespace" {
  description = "Namespace for External Secrets Operator"
  type        = string
  default     = "external-secrets"
}

variable "eso_chart_version" {
  description = "External Secrets Operator Helm chart version"
  type        = string
  default     = "0.15.1"  # Latest stable version
}

variable "service_account_secret_name" {
  description = "Name of the secret in GCP Secret Manager containing the service account key"
  type        = string
  default     = "external-secrets-service-account-key"
}

variable "service_account_secret_k8s_name" {
  description = "Name of the Kubernetes secret that will contain the service account key"
  type        = string
  default     = "gcp-secret-manager-sa"
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore resource"
  type        = string
  default     = "gcp-secret-manager"
}

variable "enable_monitoring" {
  description = "Enable ServiceMonitor for Prometheus integration"
  type        = bool
  default     = true
}

variable "wait_for_rollout" {
  description = "Wait for ESO deployment to be ready before completing"
  type        = bool
  default     = true
}
