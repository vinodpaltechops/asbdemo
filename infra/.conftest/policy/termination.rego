package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Termination protection policy: warn/block when deleting prod resources

# WARN when destroying any prod resource
warn[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  env := resource.change.before.environment

  env == "prod"

  msg := sprintf("⚠️  DESTRUCTION: Resource '%s' (type: %s) in PROD will be DELETED. This requires manual approval and careful review!", [resource.address, resource.type])
}

# WARN when destroying critical resources in any environment
warn[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions

  critical_resources := [
    "azurerm_resource_group",
    "azurerm_kubernetes_cluster",
    "azurerm_container_registry",
    "azurerm_key_vault",
    "azurerm_servicebus_namespace"
  ]

  resource.type in critical_resources

  msg := sprintf("⚠️  CRITICAL RESOURCE DELETION: Resource '%s' (type: %s) will be deleted. Please confirm this is intentional.", [resource.address, resource.type])
}

# BLOCK deletion of prod resource groups (most critical)
deny[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  resource.type == "azurerm_resource_group"
  env := resource.change.before.environment

  env == "prod"

  msg := sprintf("❌ TERMINATION BLOCKED: Cannot delete prod Resource Group '%s'. Manually enable 'destroy' override if absolutely necessary.", [resource.address])
}

# BLOCK deletion of prod AKS clusters (data loss risk)
deny[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  resource.type == "azurerm_kubernetes_cluster"
  env := resource.change.before.environment

  env == "prod"

  msg := sprintf("❌ TERMINATION BLOCKED: Cannot delete prod AKS cluster '%s'. This will lose all running workloads. Manually enable 'destroy' override if absolutely necessary.", [resource.address])
}

# BLOCK deletion of prod Key Vaults (secrets loss)
deny[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  resource.type == "azurerm_key_vault"
  env := resource.change.before.environment

  env == "prod"

  msg := sprintf("❌ TERMINATION BLOCKED: Cannot delete prod Key Vault '%s'. This will lose all secrets and keys. Manually enable 'destroy' override if absolutely necessary.", [resource.address])
}

# BLOCK deletion of prod ServiceBus (messages lost)
deny[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  resource.type == "azurerm_servicebus_namespace"
  env := resource.change.before.environment

  env == "prod"

  msg := sprintf("❌ TERMINATION BLOCKED: Cannot delete prod ServiceBus '%s'. This will lose all queues and messages. Manually enable 'destroy' override if absolutely necessary.", [resource.address])
}

# WARN when destroying resources with data
warn[msg] if {
  resource := input.resource_changes[_]
  "delete" in resource.change.actions
  resource.type == "azurerm_log_analytics_workspace"

  msg := sprintf("⚠️  DATA LOSS: Resource '%s' (Log Analytics) will be deleted. All log data will be lost.", [resource.address])
}
