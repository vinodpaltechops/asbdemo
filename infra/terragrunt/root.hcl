# Root Terragrunt config for environment orchestration
# Provides common provider configuration and inputs
# Each leaf handles its own backend configuration

locals {
  env_cfg = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    provider "azurerm" {
      features {
        resource_group {
          prevent_deletion_if_contains_resources = false
        }
        key_vault {
          purge_soft_delete_on_destroy    = true
          recover_soft_deleted_key_vaults = true
        }
      }
    }

    provider "azuread" {}
  EOT
}

inputs = {
  tags = local.env_cfg.locals.tags
}
