# ===================================================================
#  EXTERNAL SECRETS OPERATOR VARIABLES - SIMPLIFIED
# ===================================================================

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

variable "enable_ha" {
  description = "Enable high availability mode (2 replicas)"
  type        = bool
  default     = false
}

variable "wait_for_rollout" {
  description = "Wait for ESO deployment to be ready before completing"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "Log level for External Secrets Operator"
  type        = string
  default     = "info"
  
  validation {
    condition     = contains(["debug", "info", "warn", "error"], var.log_level)
    error_message = "Log level must be one of: debug, info, warn, error."
  }
}

variable "resource_limits" {
  description = "Resource limits for ESO components"
  type = object({
    controller = optional(object({
      cpu_limit      = optional(string, "200m")
      memory_limit   = optional(string, "256Mi")
      cpu_request    = optional(string, "100m")
      memory_request = optional(string, "128Mi")
    }), {})
    webhook = optional(object({
      cpu_limit      = optional(string, "100m")
      memory_limit   = optional(string, "128Mi")
      cpu_request    = optional(string, "50m")
      memory_request = optional(string, "64Mi")
    }), {})
    cert_controller = optional(object({
      cpu_limit      = optional(string, "100m")
      memory_limit   = optional(string, "128Mi")
      cpu_request    = optional(string, "50m")
      memory_request = optional(string, "64Mi")
    }), {})
  })
  default = {}
}

variable "webhook_timeout" {
  description = "Timeout for webhook operations in seconds"
  type        = number
  default     = 10
  
  validation {
    condition     = var.webhook_timeout >= 5 && var.webhook_timeout <= 30
    error_message = "Webhook timeout must be between 5 and 30 seconds."
  }
}

variable "controller_concurrent_reconciles" {
  description = "Number of concurrent reconciles for the controller"
  type        = number
  default     = 5
  
  validation {
    condition     = var.controller_concurrent_reconciles >= 1 && var.controller_concurrent_reconciles <= 20
    error_message = "Concurrent reconciles must be between 1 and 20."
  }
}

variable "enable_leader_election" {
  description = "Enable leader election for high availability"
  type        = bool
  default     = true
}

variable "metrics_port" {
  description = "Port for metrics endpoint"
  type        = number
  default     = 8080
  
  validation {
    condition     = var.metrics_port >= 1024 && var.metrics_port <= 65535
    error_message = "Metrics port must be between 1024 and 65535."
  }
}

# --- COMPUTED VALUES ---
locals {
  final_resource_limits = {
    controller = merge(
      {
        cpu_limit      = "200m"
        memory_limit   = "256Mi"
        cpu_request    = "100m"
        memory_request = "128Mi"
      },
      var.resource_limits.controller
    )
    webhook = merge(
      {
        cpu_limit      = "100m"
        memory_limit   = "128Mi"
        cpu_request    = "50m"
        memory_request = "64Mi"
      },
      var.resource_limits.webhook
    )
    cert_controller = merge(
      {
        cpu_limit      = "100m"
        memory_limit   = "128Mi"
        cpu_request    = "50m"
        memory_request = "64Mi"
      },
      var.resource_limits.cert_controller
    )
  }
  
  eso_config = {
    namespace           = var.eso_namespace
    chart_version       = var.eso_chart_version
    log_level          = var.log_level
    ha_enabled         = var.enable_ha
    monitoring_enabled = var.enable_monitoring
    replicas           = var.enable_ha ? 2 : 1
  }
}
