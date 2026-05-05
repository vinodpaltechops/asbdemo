package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Naming convention policy: all resources must follow the pattern <type>-asbdemo-<env>-<region>
# Examples: rg-asbdemo-dev-sin, vnet-asbdemo-prod-sin, aks-asbdemo-dev-sin

deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in ["azurerm_resource_group", "azurerm_virtual_network", "azurerm_subnet", "azurerm_network_security_group", "azurerm_kubernetes_cluster", "azurerm_container_registry", "azurerm_key_vault", "azurerm_log_analytics_workspace", "azurerm_servicebus_namespace"]

  name := resource.change.after.name

  # Allowed pattern: <prefix>-asbdemo-<env>-<region> or <prefix>asbdemo<env><region> (no dashes)
  not regex.match("^[a-z-]+asbdemo(dev|prod|hub)[a-z]{3}.*$", name)

  msg := sprintf("❌ NAMING: Resource '%s' (type: %s) has invalid name. Expected format: <type>-asbdemo-<env>-<region> or <type>asbdemo<env><region>. Got: '%s'", [resource.address, resource.type, name])
}

# Ensure no naming conflicts - warn if multiple resources have same name (unlikely but catch data errors)
warn[msg] if {
  resources := input.resource_changes[_]
  resource_names := [r.change.after.name | r := input.resource_changes[_]]

  # Count occurrences of each name
  name := resources.change.after.name
  count([r | r := input.resource_changes[_]; r.change.after.name == name]) > 1

  msg := sprintf("⚠️  WARNING: Multiple resources may have name '%s'. Please verify uniqueness.", [name])
}
