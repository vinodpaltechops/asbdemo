locals {
  env         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = "dev"
}

terraform {
  # Use relative path to prevent Terragrunt from copying/caching
  # This keeps module paths valid (${path.module}/../../modules works)
  source = "../../../terraform/envs/azure-dev"
}

include "root" {
  path = find_in_parent_folders("root.hcl")
}

generate "backend" {
  path      = "backend_override.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOT
    terraform {
      cloud {
        organization = "${local.env.locals.org}"
        workspaces {
          name = "${local.environment}"
        }
      }
    }
  EOT
}

inputs = {
  environment = local.environment
}
