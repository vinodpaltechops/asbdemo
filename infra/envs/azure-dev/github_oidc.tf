data "azurerm_subscription" "current" {}

resource "azuread_application" "github_ci" {
  display_name = "github-${local.prefix}-ci"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "github_ci" {
  client_id = azuread_application.github_ci.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github_main" {
  application_id = azuread_application.github_ci.id
  display_name   = "github-main"
  description    = "GitHub Actions on main branch"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:ref:refs/heads/main"
}

resource "azuread_application_federated_identity_credential" "github_pr" {
  application_id = azuread_application.github_ci.id
  display_name   = "github-pr"
  description    = "GitHub Actions on pull requests"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "repo:${var.github_repo}:pull_request"
}

resource "azurerm_role_assignment" "github_ci_acrpush" {
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.github_ci.object_id
}

resource "azurerm_role_assignment" "github_ci_aks_user" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.github_ci.object_id
}
