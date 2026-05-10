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
  description = "Environment label."
  type        = string
  default     = "hub"
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

variable "hub_vnet_address_space" {
  description = "Address space for the hub VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
