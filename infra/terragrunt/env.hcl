locals {
  org            = "vinod-techops-org"
  env_name_prod  = "azure-prod"
  env_name_dev   = "azure-dev"
  env_name_hub   = "azure-hub"
  location       = "southindia"
  location_short = "sin"
  app_name       = "asbdemo"
  environment    = "dev"
  tags = {
    app        = local.app_name
    environment = local.environment
    managed_by = "terraform"
    repo       = "azureservicebus"
  }
}
