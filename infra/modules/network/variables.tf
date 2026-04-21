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
  description = "Map of subnet name -> { cidr = string }."
  type = map(object({
    cidr = string
  }))
}

variable "nsg_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
