package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Tags policy: all resources must have required tags for compliance, billing, and tracking

required_tags := ["app", "environment", "managed_by", "repo"]

# Deny resources without required tags
deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in ["azurerm_resource_group", "azurerm_virtual_network", "azurerm_kubernetes_cluster", "azurerm_container_registry", "azurerm_key_vault", "azurerm_log_analytics_workspace", "azurerm_servicebus_namespace", "azurerm_managed_disk", "azurerm_network_interface"]

  tags := resource.change.after.tags
  tags == null

  msg := sprintf("❌ TAGS: Resource '%s' (type: %s) has no tags. Required tags: %v", [resource.address, resource.type, required_tags])
}

# Deny resources missing specific required tags
deny[msg] if {
  resource := input.resource_changes[_]
  resource.type in ["azurerm_resource_group", "azurerm_virtual_network", "azurerm_kubernetes_cluster", "azurerm_container_registry", "azurerm_key_vault", "azurerm_log_analytics_workspace", "azurerm_servicebus_namespace", "azurerm_managed_disk", "azurerm_network_interface"]

  tags := resource.change.after.tags
  tags != null

  missing_tags := [tag | tag := required_tags[_]; not tags[tag]]
  count(missing_tags) > 0

  msg := sprintf("❌ TAGS: Resource '%s' (type: %s) missing required tags: %v", [resource.address, resource.type, missing_tags])
}

# Warn if tag values are suspicious (empty, or just placeholders)
warn[msg] if {
  resource := input.resource_changes[_]
  tags := resource.change.after.tags
  tags != null

  tag_name := "environment"
  tag_value := tags[tag_name]
  tag_value in ["", "unknown", "placeholder", "TODO"]

  msg := sprintf("⚠️  TAGS: Resource '%s' has suspicious value for tag '%s': '%s'. Please set proper value.", [resource.address, tag_name, tag_value])
}

# Ensure 'environment' tag matches the actual environment being deployed
warn[msg] if {
  resource := input.resource_changes[_]
  tags := resource.change.after.tags
  tags != null

  tag_env := tags.environment
  config_env := resource.change.after.environment

  config_env != null
  tag_env != config_env

  msg := sprintf("⚠️  TAGS: Resource '%s' has environment tag '%s' but config specifies '%s'. Please match.", [resource.address, tag_env, config_env])
}
