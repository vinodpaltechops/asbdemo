package terraform

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Cost control policy: prevent expensive SKUs in dev environment to control costs

# Block Premium/expensive ACR SKUs in dev
deny[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_container_registry"
  sku := resource.change.after.sku
  env := resource.change.after.environment

  expensive_skus := ["Premium"]
  sku in expensive_skus
  env == "dev"

  msg := sprintf("❌ COST: Resource '%s' (ACR) cannot use SKU '%s' in dev environment. Use 'Basic' for dev. Cost impact: Premium=$200+/mo vs Basic=$5/mo", [resource.address, sku])
}

# Block Premium/Standard ServiceBus SKUs in dev
deny[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_servicebus_namespace"
  sku := resource.change.after.sku
  env := resource.change.after.environment

  expensive_skus := ["Premium", "Standard"]
  sku in expensive_skus
  env == "dev"

  msg := sprintf("❌ COST: Resource '%s' (ServiceBus) uses SKU '%s' in dev. Consider 'Basic' for development. Cost: Premium=$329/mo, Standard=$10/mo", [resource.address, sku])
}

# Warn about large VM sizes in dev
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_kubernetes_cluster"
  env := resource.change.after.environment

  system_vm_size := resource.change.after.default_node_pool[0].vm_size
  env == "dev"

  large_vms := ["Standard_D4s_v4", "Standard_D4s_v5", "Standard_D8s_v4", "Standard_D8s_v5", "Standard_E4s_v3", "Standard_E4s_v4"]
  system_vm_size in large_vms

  msg := sprintf("⚠️  COST: AKS system nodepool in dev uses large VM size '%s'. Cost impact: ~$150+/mo. Consider smaller size for dev.", [system_vm_size])
}

# Warn about excessive log retention (costs accumulate)
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_log_analytics_workspace"
  env := resource.change.after.environment

  retention := resource.change.after.retention_in_days
  env == "dev"
  retention > 90

  msg := sprintf("⚠️  COST: Log Analytics workspace in dev has %d days retention. Cost: ~$10/mo per 100GB. Consider 30 days for dev.", [retention])
}

# Warn about excessive max AKS nodes
warn[msg] if {
  resource := input.resource_changes[_]
  resource.type == "azurerm_kubernetes_cluster"
  env := resource.change.after.environment
  env == "dev"

  user_node_pool := resource.change.after.default_node_pool[0]
  max_count := user_node_pool.max_count

  max_count > 5

  msg := sprintf("⚠️  COST: AKS user nodepool max_count is %d in dev. With autoscaling, this could cost $300+/mo. Consider max_count=3 for dev.", [max_count])
}
