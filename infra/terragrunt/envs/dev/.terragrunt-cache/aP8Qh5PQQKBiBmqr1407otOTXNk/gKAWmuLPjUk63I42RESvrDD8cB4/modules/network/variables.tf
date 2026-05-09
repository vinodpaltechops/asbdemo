variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "address_space" {
  type = list(string)
}

variable "subnets" {
  description = "Map of subnet name -> { cidr, optional aks_pod_delegation }."
  type = map(object({
    cidr               = string
    aks_pod_delegation = optional(bool, false)
  }))
}

variable "nsg_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
