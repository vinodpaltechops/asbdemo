data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

resource "azurerm_resource_group" "main" {
  name     = local.names.rg
  location = var.location
  tags     = local.tags
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                = local.names.law
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = local.names.vnet
  address_space       = var.vnet_address_space
  subnets             = local.subnets
  nsg_name            = local.names.nsg_aks
  tags                = local.tags
}

module "keyvault" {
  source = "../../modules/keyvault"

  name                = local.names.kv
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.tags
}

module "acr" {
  source = "../../modules/acr"

  name                = local.names.acr
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  tags                = local.tags
}

module "aks" {
  source = "../../modules/aks"

  name                = local.names.aks
  dns_prefix          = local.names.aks_dns_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  kubernetes_version  = var.kubernetes_version

  system_subnet_id    = module.network.subnet_ids["aks-system"]
  pod_subnet_id       = module.network.subnet_ids["aks-user"]
  system_node_vm_size = var.aks_system_node_vm_size
  system_node_count   = var.aks_system_node_count
  user_node_vm_size   = var.aks_user_node_vm_size
  user_node_min_count = var.aks_user_node_min_count
  user_node_max_count = var.aks_user_node_max_count
  log_analytics_id    = module.monitoring.workspace_id
  acr_id              = module.acr.id

  tags = local.tags
}

module "servicebus" {
  source = "../../modules/servicebus"

  namespace_name      = local.names.sb
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  queue_names         = [var.servicebus_queue_name]
  tags                = local.tags
}

# Workload identity for the orders (producer) service
module "wi_orders" {
  source = "../../modules/workload-identity"

  name                = local.names.mi_orders
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  aks_oidc_issuer_url = module.aks.oidc_issuer_url
  k8s_namespace       = var.apps_namespace
  k8s_service_account = "orders-sa"

  role_assignments = [
    {
      scope = module.servicebus.queue_ids[var.servicebus_queue_name]
      role  = "Azure Service Bus Data Sender"
    }
  ]

  tags = local.tags
}

# Workload identity for the payments (consumer) service
module "wi_payments" {
  source = "../../modules/workload-identity"

  name                = local.names.mi_payments
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  aks_oidc_issuer_url = module.aks.oidc_issuer_url
  k8s_namespace       = var.apps_namespace
  k8s_service_account = "payments-sa"

  role_assignments = [
    {
      scope = module.servicebus.queue_ids[var.servicebus_queue_name]
      role  = "Azure Service Bus Data Receiver"
    }
  ]

  tags = local.tags
}
