# Dev environment values — referenced by every leaf under live/dev/.
#
# Resource sizing and toggles also live here once we decompose the
# wrapped root into per-component leaves.

locals {
  environment    = "dev"
  location       = "southindia"
  location_short = "sin"

  # HCP workspace for this env. Currently hardcoded in
  # infra/envs/azure-dev/versions.tf cloud{} block. Once we move that
  # into a Terragrunt-generated backend.tf, this local becomes the
  # source of truth.
  hcp_workspace = "azure-dev"
}

inputs = {
  environment    = local.environment
  location       = local.location
  location_short = local.location_short
}
