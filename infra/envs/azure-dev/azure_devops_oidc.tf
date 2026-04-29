# Azure DevOps CI identity (OIDC / Workload Identity Federation)
#
# The AAD app + service principal + role assignments are provisioned here.
# The federated credential's issuer/subject must come from an ADO service
# connection created in the UI ("Workload Identity Federation (manual)") —
# paste the values into terraform.tfvars (azure_devops_wif_issuer/subject).
#
# Until those vars are populated the federated credential is not created;
# the AAD app and role assignments are still applied so the SP exists.

locals {
  ado_wif_configured = (
    var.azure_devops_wif_issuer != "" &&
    var.azure_devops_wif_subject != ""
  )
}

resource "azuread_application" "ado_ci" {
  display_name = "ado-${local.prefix}-ci"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "ado_ci" {
  client_id = azuread_application.ado_ci.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "ado_sc" {
  count = local.ado_wif_configured ? 1 : 0

  application_id = azuread_application.ado_ci.id
  display_name   = "ado-service-connection"
  description    = "Azure DevOps service connection (workload identity federation)"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.azure_devops_wif_issuer
  subject        = var.azure_devops_wif_subject
}

# Push images to ACR
resource "azurerm_role_assignment" "ado_ci_acrpush" {
  scope                = module.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azuread_service_principal.ado_ci.object_id
}

# Pull AKS kubeconfig if we ever run kubectl from the pipeline
resource "azurerm_role_assignment" "ado_ci_aks_user" {
  scope                = module.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azuread_service_principal.ado_ci.object_id
}

# Read pipeline secrets out of Key Vault (KV is RBAC-enabled)
resource "azurerm_role_assignment" "ado_ci_kv_secrets_user" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azuread_service_principal.ado_ci.object_id
}
