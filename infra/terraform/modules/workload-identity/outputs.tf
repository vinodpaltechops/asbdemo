output "id" {
  value = azurerm_user_assigned_identity.this.id
}

output "name" {
  value = azurerm_user_assigned_identity.this.name
}

output "client_id" {
  description = "Annotate this on the k8s ServiceAccount: azure.workload.identity/client-id"
  value       = azurerm_user_assigned_identity.this.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.this.principal_id
}
