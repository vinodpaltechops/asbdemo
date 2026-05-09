locals {
  prefix = "${var.app_name}-${var.environment}-${var.location_short}"

  names = {
    rg   = "rg-${local.prefix}"
    vnet = "vnet-hub-${local.prefix}"
  }

  tags = merge(
    {
      app         = var.app_name
      environment = var.environment
      managed_by  = "terraform"
      repo        = "azureservicebus"
      workspace   = "vinod-techops-org/azure-hub"
    },
    var.tags
  )
}
