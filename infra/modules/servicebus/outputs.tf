output "namespace_id" {
  value = azurerm_servicebus_namespace.this.id
}

output "namespace_name" {
  value = azurerm_servicebus_namespace.this.name
}

output "namespace_fqdn" {
  value = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
}

output "queue_ids" {
  description = "Map of queue name -> resource id (used as RBAC scope)."
  value       = { for k, q in azurerm_servicebus_queue.this : k => q.id }
}
