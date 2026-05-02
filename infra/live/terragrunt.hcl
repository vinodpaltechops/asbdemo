# Root Terragrunt config — inherited by every environment leaf.
#
# Pulls per-env values from env.hcl (region, sizing, naming).
# Backend / cloud {} block is left in the wrapped Terraform root for
# Phase A. Once we decompose into per-component leaves (Phase A.2+),
# this root will generate them.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = merge(
  local.env_vars.inputs,
)
