output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "vnet_name" {
  value = azurerm_virtual_network.this.name
}

output "subnet_ids" {
  description = "Map of subnet name -> subnet id."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}
