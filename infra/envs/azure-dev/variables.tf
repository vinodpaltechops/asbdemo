variable "app_name" {
  description = "Application short name; drives all resource names."
  type        = string
  default     = "asbdemo"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.app_name))
    error_message = "app_name must be 3-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Environment label (dev/stage/prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "southindia"
}

variable "location_short" {
  description = "Short region code used in resource names."
  type        = string
  default     = "sin"
}

variable "vnet_address_space" {
  description = "Address space for the workload VNet."
  type        = list(string)
  default     = ["10.40.0.0/16"]
}

variable "aks_system_node_vm_size" {
  description = "VM size for AKS system nodepool."
  type        = string
  default     = "Standard_B2als_v2"
}

variable "aks_user_node_vm_size" {
  description = "VM size for AKS user nodepool."
  type        = string
  default     = "Standard_B2as_v2"
}

variable "aks_system_node_count" {
  description = "Number of system nodes (kube-system workloads only)."
  type        = number
  default     = 1
}

variable "aks_user_node_min_count" {
  description = "Minimum user nodes (autoscaled)."
  type        = number
  default     = 1
}

variable "aks_user_node_max_count" {
  description = "Maximum user nodes (autoscaled)."
  type        = number
  default     = 3
}

variable "kubernetes_version" {
  description = "AKS Kubernetes version. Leave null to use current default."
  type        = string
  default     = null
}

variable "servicebus_queue_name" {
  description = "Primary Service Bus queue for the demo."
  type        = string
  default     = "orders"
}

variable "apps_namespace" {
  description = "Kubernetes namespace for the workload apps."
  type        = string
  default     = "asbdemo"
}

variable "log_retention_days" {
  description = "Log Analytics workspace retention."
  type        = number
  default     = 30
}
