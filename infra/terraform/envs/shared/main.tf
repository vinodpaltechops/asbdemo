data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# ════════════════════════════════════════════════════════════════════════════
# EXTERNAL RESOURCES (Manually Created in Azure)
# ════════════════════════════════════════════════════════════════════════════
# Reference manually created resources without managing them via Terraform.
# Uncomment and customize based on your actual external resources.
# See: docs/TERRAFORM_STATE_MANAGEMENT.md for full examples.
# ════════════════════════════════════════════════════════════════════════════

# Example 1: Reference an external Storage Account
# data "azurerm_storage_account" "external_db_storage" {
#   name                = "myexternalstorage"          # Replace with actual name
#   resource_group_name = "my-external-rg"             # Replace with actual RG
# }

# Example 2: Reference an external SQL Database
# data "azurerm_mssql_server" "external_database" {
#   name                = "my-sql-server"
#   resource_group_name = "my-external-rg"
# }
#
# data "azurerm_mssql_database" "external_database" {
#   name            = "my-database"
#   server_id       = data.azurerm_mssql_server.external_database.id
# }

# Example 3: Reference an external Virtual Network
# data "azurerm_virtual_network" "external_vnet" {
#   name                = "external-vnet"
#   resource_group_name = "my-external-rg"
# }
#
# data "azurerm_subnet" "external_subnet" {
#   name                 = "app-subnet"
#   virtual_network_name = data.azurerm_virtual_network.external_vnet.name
#   resource_group_name  = "my-external-rg"
# }

# Example 4: Reference an external Resource Group
# data "azurerm_resource_group" "external_rg" {
#   name = "my-external-rg"
# }

# Example 5: Reference an external Key Vault
# data "azurerm_key_vault" "external_vault" {
#   name                = "my-external-vault"
#   resource_group_name = "my-external-rg"
# }

# Example 6: Reference external App Service
# data "azurerm_app_service" "external_app" {
#   name                = "my-external-app"
#   resource_group_name = "my-external-rg"
# }

# Example 7: Reference external Virtual Machine
# data "azurerm_virtual_machine" "external_vm" {
#   name                = "my-vm"
#   resource_group_name = "my-external-rg"
# }

# Example 8: Reference external Network Security Group
# data "azurerm_network_security_group" "external_nsg" {
#   name                = "external-nsg"
#   resource_group_name = "my-external-rg"
# }

# ════════════════════════════════════════════════════════════════════════════
# USAGE: Once uncommented and configured, reference data sources like:
# ════════════════════════════════════════════════════════════════════════════
#
# Example: Use external database connection in app service configuration:
#   app_settings = {
#     DATABASE_SERVER = data.azurerm_mssql_server.external_database.fully_qualified_domain_name
#     DATABASE_NAME   = data.azurerm_mssql_database.external_database.name
#   }
#
# Example: Use external storage account in AKS pod mount:
#   storage_account_name  = data.azurerm_storage_account.external_db_storage.name
#   storage_account_key   = data.azurerm_storage_account.external_db_storage.primary_access_key
#
# ════════════════════════════════════════════════════════════════════════════

locals {
  prefix        = "${var.app_name}-${var.environment}-${var.location_short}"
  prefix_nodash = "${var.app_name}${var.environment}${var.location_short}"

  names = {
    rg             = "rg-${local.prefix}"
    vnet           = "vnet-${local.prefix}"
    nsg_aks        = "nsg-aks-${local.prefix}"
    kv             = "kv-${local.prefix}"
    acr            = "acr${local.prefix_nodash}"
    law            = "log-${local.prefix}"
    aks            = "aks-${local.prefix}"
    aks_dns_prefix = "aks-${local.prefix}"
    sb             = "sb-${local.prefix}-${random_string.sb_suffix.result}"
    mi_orders      = "mi-orders-${local.prefix}"
    mi_payments    = "mi-payments-${local.prefix}"
  }

  subnets = {
    aks-system = { cidr = var.subnet_aks_system_cidr }
    aks-user   = { cidr = var.subnet_aks_user_cidr, aks_pod_delegation = true }
    pe         = { cidr = var.subnet_pe_cidr }
  }

  tags = {
    app         = var.app_name
    environment = var.environment
    managed_by  = "terraform"
    repo        = "azureservicebus"
    workspace   = "vinod-techops-org/azure-${var.environment}"
  }
}

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

module "servicebus" {
  source = "../../modules/servicebus"

  namespace_name      = local.names.sb
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  queue_names         = [var.servicebus_queue_name]
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

resource "random_string" "sb_suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}

# RBAC: Role-based access control for resource group
# Restricts who can manage resources based on environment

resource "azurerm_role_assignment" "dev_contributor" {
  count = var.environment == "dev" && var.dev_team_group_id != "" ? 1 : 0

  scope              = azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_type = "Group"
  principal_id   = var.dev_team_group_id

  lifecycle {
    ignore_changes = [principal_id]
  }
}

resource "azurerm_role_assignment" "prod_owner" {
  count = var.environment == "prod" && var.prod_team_group_id != "" ? 1 : 0

  scope              = azurerm_resource_group.main.id
  role_definition_name = "Owner"
  principal_type = "Group"
  principal_id   = var.prod_team_group_id

  lifecycle {
    ignore_changes = [principal_id]
  }
}

resource "azurerm_role_assignment" "prod_reader" {
  count = var.environment == "prod" && var.prod_ops_group_id != "" ? 1 : 0

  scope              = azurerm_resource_group.main.id
  role_definition_name = "Reader"
  principal_type = "Group"
  principal_id   = var.prod_ops_group_id

  lifecycle {
    ignore_changes = [principal_id]
  }
}
