# Root Terragrunt config for environment orchestration
# Provides common provider configuration, absolute paths, and inputs
# Each leaf handles its own backend configuration

locals {
  # Find the repo root using the .terragrunt-root marker file
  repo_root     = dirname(find_in_parent_folders(".terragrunt-root"))
  terraform_dir = "${local.repo_root}/infra/terraform"
  modules_dir   = "${local.terraform_dir}/modules"
  env_cfg       = read_terragrunt_config(find_in_parent_folders("env.hcl"))
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
  tags          = local.env_cfg.locals.tags
  repo_root     = local.repo_root
  terraform_dir = local.terraform_dir
  modules_dir   = local.modules_dir
}
