locals {
  # Name prefix: <type>-<app>-<env>-<region-short>
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
    aks-system = { cidr = "10.40.1.0/24" }
    aks-user   = { cidr = "10.40.2.0/24", aks_pod_delegation = true }
    pe         = { cidr = "10.40.10.0/24" }
  }

  tags = {
    app         = var.app_name
    environment = var.environment
    managed_by  = "terraform"
    repo        = "azureservicebus"
    workspace   = "vinod-techops-org/azure-dev"
  }
}

# Service Bus namespace name must be globally unique; random suffix guarantees that.
resource "random_string" "sb_suffix" {
  length  = 4
  upper   = false
  special = false
  numeric = true
}
