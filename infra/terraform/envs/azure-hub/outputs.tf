output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "hub_vnet_address_space" {
  value = azurerm_virtual_network.hub.address_space
}

output "gateway_subnet_id" {
  description = "Gateway subnet ID for future VPN Gateway or ExpressRoute wiring."
  value       = azurerm_subnet.gateway.id
}
