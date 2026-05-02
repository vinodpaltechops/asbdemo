# Dev leaf — wraps the existing infra/envs/azure-dev/ Terraform root.
#
# Phase A: thin wrapper. State stays in HCP workspace "azure-dev"
# (hardcoded in the wrapped root's versions.tf cloud{} block).
# `terragrunt plan` here should be byte-equivalent to running
# `terraform plan` from infra/envs/azure-dev/ directly.

include "root" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source = "../../envs/azure-dev"
}
