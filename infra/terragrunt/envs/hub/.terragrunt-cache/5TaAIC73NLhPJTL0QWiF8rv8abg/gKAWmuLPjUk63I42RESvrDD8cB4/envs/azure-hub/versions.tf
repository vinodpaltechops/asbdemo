terraform {
  required_version = ">= 1.9.0"

  cloud {
    organization = "vinod-techops-org"

    workspaces {
      name = "azure-hub"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
