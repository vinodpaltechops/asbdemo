package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# RBAC policy: ensure proper role-based access control is configured for sensitive resources

# Warn if prod resource group has no role assignments defined
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_resource_group"
  env := resource.change.after.environment

  env == "prod"

  # Check if there are any role assignment resources that reference this RG
  role_assignments := [r | r := input.resource_changes[_]; r.type == "azurerm_role_assignment"; contains(r.change.after.scope, resource.change.after.id)]
  count(role_assignments) == 0

  msg := sprintf("⚠️  RBAC: Prod Resource Group '%s' has no role assignments defined. Consider adding restricted access for team members.", [resource.address])
}

# Warn if Key Vault has no access policies
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_key_vault"
  env := resource.change.after.environment

  env in ["dev", "prod"]

  access_policies := resource.change.after.access_policy
  access_policies == null

  msg := sprintf("⚠️  RBAC: Key Vault '%s' has no access policies defined. Configure access policies to restrict who can read/write secrets.", [resource.address])
}

# Warn if AKS cluster lacks proper RBAC configuration
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_kubernetes_cluster"

  # Check if role_based_access_control_enabled is false or missing
  rbac_enabled := resource.change.after.role_based_access_control_enabled
  rbac_enabled == false

  msg := sprintf("⚠️  RBAC: AKS cluster '%s' has RBAC disabled. Enable role_based_access_control_enabled for proper Kubernetes RBAC.", [resource.address])
}

# Deny excessive permissions (Owner role on anything other than specific groups)
deny[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_role_assignment"
  role := resource.change.after.role_definition_name

  role == "Owner"
  scope := resource.change.after.scope

  # Owner role should only be on Resource Groups for specific teams, not on individual resources
  not contains(scope, "/resourceGroups/")

  msg := sprintf("❌ RBAC: Resource '%s' grants 'Owner' role on a non-RG scope. Owner should only be assigned at Resource Group level for team leads.", [resource.address])
}

# Warn if using deprecated roles
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_role_assignment"
  role := resource.change.after.role_definition_name

  deprecated_roles := ["Contributor", "Administrator"]
  role in deprecated_roles

  msg := sprintf("⚠️  RBAC: Resource '%s' uses deprecated role '%s'. Consider using more specific roles like 'AKS Cluster Admin' or 'Key Vault Admin'.", [resource.address, role])
}

# Warn if principal_id is missing (orphaned role assignment)
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_role_assignment"
  principal := resource.change.after.principal_id

  principal == null

  msg := sprintf("⚠️  RBAC: Role assignment '%s' has no principal_id. This will not grant access to anyone.", [resource.address])
}
