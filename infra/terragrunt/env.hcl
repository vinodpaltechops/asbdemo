locals {
  org            = "vinod-techops-org"
  env_name_prod  = "azure-prod"
  env_name_dev   = "azure-dev"
  env_name_hub   = "azure-hub"
  location       = "southindia"
  location_short = "sin"
  app_name       = "asbdemo"
  environment    = "dev"

  # Azure Storage Account backend configuration for Terraform state
  backend_rg = "rg-${local.app_name}-tfstate-${local.location_short}"
  backend_sa = "st${local.app_name}tfstate${local.location_short}"

  tags = {
    app        = local.app_name
    environment = local.environment
    managed_by = "terraform"
    repo       = "azureservicebus"
  }
}
