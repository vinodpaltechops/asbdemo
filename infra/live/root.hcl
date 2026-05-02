# Root Terragrunt config — inherited by every environment leaf.
#
# Phase A.1 keeps this minimal because the only leaf (dev) wraps an
# existing self-contained Terraform root that already declares its
# own backend (HCP cloud{} block) and providers.
#
# In Phase A.2 this root will:
#   - generate("backend") emitting a parameterized cloud{} block
#     (workspace name pulled from each env.hcl)
#   - generate("provider") emitting common azurerm/azuread provider
#     config so leaves don't repeat it
#   - read env.hcl to feed shared inputs into every leaf
