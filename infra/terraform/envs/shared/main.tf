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
# USAGE: Data Sources (Reference Only — No State Management)
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

# ════════════════════════════════════════════════════════════════════════════
# IMPORTING EXTERNAL RESOURCES (Take Under Terraform Management)
# ════════════════════════════════════════════════════════════════════════════
#
# If you want to MANAGE external resources via Terraform (instead of just reading),
# you need to:
#   1. Write the Terraform resource block matching the external resource config
#   2. Run: terraform import <resource_type>.<name> <azure_resource_id>
#   3. Verify state is updated
#
# STEP-BY-STEP IMPORT EXAMPLE
# ════════════════════════════════════════════════════════════════════════════
#
# Let's say you manually created a storage account in Azure Portal:
#   Name: myexternalstorage
#   Resource Group: my-external-rg
#   Location: southindia
#   Account Tier: Standard
#   Replication: LRS
#
# STEP 1: Write the Terraform resource block
# ─────────────────────────────────────────────────────────────────────────────
# resource "azurerm_storage_account" "imported_external" {
#   name                     = "myexternalstorage"
#   resource_group_name      = "my-external-rg"
#   location                 = "southindia"
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   https_traffic_only_enabled = true
#
#   tags = local.tags
# }
#
# STEP 2: Get the Azure Resource ID
# ─────────────────────────────────────────────────────────────────────────────
# Option A: Use Azure Portal
#   → Go to resource
#   → Click "JSON View" (bottom right)
#   → Copy the "id" field
#   Example: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage
#
# Option B: Use Azure CLI
#   $ az storage account show \
#       --name myexternalstorage \
#       --resource-group my-external-rg \
#       --query id -o tsv
#   Output: /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage
#
# STEP 3: Import the resource into Terraform state
# ─────────────────────────────────────────────────────────────────────────────
# cd infra/terragrunt/envs/dev
#
# terragrunt import azurerm_storage_account.imported_external \
#   '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage'
#
# Expected output:
#   azurerm_storage_account.imported_external: Importing from ID "/subscriptions/.../storageAccounts/myexternalstorage"...
#   azurerm_storage_account.imported_external: Import successful!
#
#   Apply complete! Resources: 1 added.
#
# STEP 4: Verify it's in state
# ─────────────────────────────────────────────────────────────────────────────
# terragrunt state list
# # Output should include:
# # azurerm_storage_account.imported_external
#
# terragrunt state show azurerm_storage_account.imported_external
# # Should show all the properties from Azure
#
# STEP 5: Verify plan shows no changes
# ─────────────────────────────────────────────────────────────────────────────
# terragrunt plan
# # Should output: No changes. Your infrastructure matches the configuration.
# # (If it shows changes, your Terraform config doesn't match Azure reality - fix it)
#
# STEP 6: Now it's managed! You can:
# ─────────────────────────────────────────────────────────────────────────────
#   ✅ Update the resource: terraform apply (Terraform will update Azure)
#   ✅ Destroy the resource: terraform destroy (Terraform will delete it)
#   ✅ Reference it: Use the resource name in other configs
#   ✅ Track changes: terraform plan shows any drift
#
# ════════════════════════════════════════════════════════════════════════════
#
# COMMON AZURE RESOURCE IMPORT EXAMPLES
# ════════════════════════════════════════════════════════════════════════════
#
# Resource Type | Terraform Block | Azure Resource ID Format
# ──────────────┼─────────────────┼─────────────────────────────────────────
# Storage Acct  | azurerm_storage_account | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{name}
# SQL Server    | azurerm_mssql_server    | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Sql/servers/{name}
# SQL Database  | azurerm_mssql_database  | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Sql/servers/{server}/databases/{name}
# Virtual Network | azurerm_virtual_network | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{name}
# Subnet        | azurerm_subnet          | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/virtualNetworks/{vnet}/subnets/{name}
# Resource Group | azurerm_resource_group  | /subscriptions/{sub}/resourceGroups/{rg}
# Key Vault     | azurerm_key_vault       | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.KeyVault/vaults/{name}
# App Service   | azurerm_app_service     | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{name}
# VM            | azurerm_virtual_machine | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{name}
# NSG           | azurerm_network_security_group | /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/networkSecurityGroups/{name}
#
# ════════════════════════════════════════════════════════════════════════════
#
# TROUBLESHOOTING IMPORTS
# ════════════════════════════════════════════════════════════════════════════
#
# Problem: "Error: ResourceNotFound"
# Solution: Verify resource exists in Azure and ID is correct
#   $ az resource show --id "<your-resource-id>"
#
# Problem: "Error: resource already exists in state"
# Solution: Import with a different resource name, or remove from state first
#   $ terraform state rm azurerm_storage_account.imported_external
#   $ terraform import azurerm_storage_account.imported_external <id>
#
# Problem: "Plan shows changes after import (drift)"
# Solution: Your Terraform config doesn't match Azure. Either:
#   a) Update Terraform config to match Azure reality
#   b) Run terraform apply to change Azure to match Terraform
#
# Problem: "Can't import - invalid resource type"
# Solution: Not all Azure resources support import. Check Terraform Azure provider docs.
#   https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
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
