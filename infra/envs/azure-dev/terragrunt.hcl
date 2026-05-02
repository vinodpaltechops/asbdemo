# Dev leaf — Phase A.1.
#
# Co-located with the Terraform root (main.tf et al). Terragrunt runs
# `terraform init/plan/apply` from THIS directory directly, so the
# wrapped TF code's `../../modules/*` references resolve as-is — no
# source copy, no cache surprises.
#
# State: HCP workspace "azure-dev" (cloud{} block in versions.tf).
#
# In Phase A.2 the monolithic main.tf gets split into per-component
# leaves (e.g. envs/azure-dev/network/terragrunt.hcl) that source
# individual modules and use `dependency` blocks. This file goes away
# when that happens.

include "root" {
  path = find_in_parent_folders("root.hcl")
}
