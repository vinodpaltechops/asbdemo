locals {
  env         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = "hub"
}

terraform {
  source = "../../../terraform//envs/azure-hub"
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
          name = "${local.env.locals.env_name_hub}"
        }
      }
    }
  EOT
}

inputs = {
  environment = local.environment
}
