resource "azurerm_servicebus_namespace" "this" {
  name                          = var.namespace_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku
  local_auth_enabled            = true
  public_network_access_enabled = true
  minimum_tls_version           = "1.2"
  tags                          = var.tags
}

resource "azurerm_servicebus_queue" "this" {
  for_each = toset(var.queue_names)

  name         = each.value
  namespace_id = azurerm_servicebus_namespace.this.id

  max_delivery_count                   = 10
  dead_lettering_on_message_expiration = true
  default_message_ttl                  = "P14D"
  lock_duration                        = "PT1M"
}
