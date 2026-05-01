variable "name" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = null
}

variable "system_subnet_id" {
  description = "Subnet ID for node NICs (both nodepools)."
  type        = string
}

variable "pod_subnet_id" {
  description = "Subnet ID for pod IPs (Azure CNI Dynamic IP Allocation)."
  type        = string
}

variable "system_node_vm_size" {
  type    = string
  default = "Standard_B2als_v2"
}

variable "system_node_count" {
  type    = number
  default = 1
}

variable "user_node_vm_size" {
  type    = string
  default = "Standard_D2s_v4"
}

variable "user_node_min_count" {
  type    = number
  default = 1
}

variable "user_node_max_count" {
  type    = number
  default = 3
}

variable "log_analytics_id" {
  type = string
}

variable "acr_id" {
  description = "ACR resource ID; kubelet identity gets AcrPull on it."
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
