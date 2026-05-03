locals {
  env         = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  environment = "prod"
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
