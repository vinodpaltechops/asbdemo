locals {
  env         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = "dev"
}

terraform {
  source = "../../../terraform//envs/shared"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

generate "backend" {
  path      = "backend_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      backend "azurerm" {
        resource_group_name  = "${local.env.locals.backend_rg}"
        storage_account_name = "${local.env.locals.backend_sa}"
        container_name       = "tfstate-dev"
        key                  = "dev.terraform.tfstate"
        use_oidc             = true
      }
    }
  EOT
}

inputs = {
  environment              = local.environment
  vnet_address_space       = ["10.40.0.0/16"]
  subnet_aks_system_cidr   = "10.40.1.0/24"
  subnet_aks_user_cidr     = "10.40.2.0/24"
  subnet_pe_cidr           = "10.40.10.0/24"
  aks_system_node_count    = 1
  aks_user_node_min_count  = 2  # Scaled for platform + workloads
  aks_user_node_max_count  = 3  # Allow burst for elastic-stack
  log_retention_days       = 30
}
