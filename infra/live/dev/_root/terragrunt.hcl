# Dev "_root" leaf — wraps the existing infra/envs/azure-dev/ Terraform root.
#
# Phase A.1: thin wrapper. State stays in HCP workspace "azure-dev"
# (cloud{} block is hardcoded inside the wrapped root's versions.tf).
# `terragrunt plan` here should be byte-equivalent to running
# `terraform plan` from infra/envs/azure-dev/ directly.
#
# Once we decompose into per-component leaves in Phase A.2 (network,
# aks, servicebus, observability), this `_root` directory disappears.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../envs/azure-dev"
}
