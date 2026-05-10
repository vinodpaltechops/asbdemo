variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "aks_oidc_issuer_url" {
  type = string
}

variable "k8s_namespace" {
  type = string
}

variable "k8s_service_account" {
  type = string
}

variable "role_assignments" {
  description = "List of RBAC assignments for this identity."
  type = list(object({
    scope = string
    role  = string
  }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
