# Dev leaf — wraps the existing infra/envs/azure-dev/ Terraform root.
#
# Phase A.1: thin wrapper. State stays in HCP workspace "azure-dev"
# (cloud{} block is hardcoded inside the wrapped root's versions.tf).
# `terragrunt plan` here should be byte-equivalent to running
# `terraform plan` from infra/envs/azure-dev/ directly.
#
# include_in_copy pulls infra/modules/** alongside the env source so
# the cached working dir preserves the original `../../modules/*`
# relative module references.
#
# Once we decompose into per-component leaves in Phase A.2 (network,
# aks, servicebus, observability), each leaf will source a single
# module directly and this wrapper goes away.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../envs/azure-dev"
  include_in_copy = [
    "../../modules/**",
  ]
}
