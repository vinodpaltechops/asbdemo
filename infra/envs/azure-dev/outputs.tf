output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_name" {
  value = module.aks.name
}

output "aks_oidc_issuer_url" {
  value = module.aks.oidc_issuer_url
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "key_vault_uri" {
  value = module.keyvault.uri
}

output "servicebus_namespace" {
  value = module.servicebus.namespace_name
}

output "servicebus_fqdn" {
  value = module.servicebus.namespace_fqdn
}

output "workload_identities" {
  description = "Client IDs to annotate onto the corresponding k8s ServiceAccounts."
  value = {
    orders = {
      client_id       = module.wi_orders.client_id
      service_account = "orders-sa"
      namespace       = var.apps_namespace
    }
    payments = {
      client_id       = module.wi_payments.client_id
      service_account = "payments-sa"
      namespace       = var.apps_namespace
    }
  }
}

output "github_actions_client_id" {
  description = "Client ID (appId) of the AAD app federated with GitHub Actions; set as repo variable AZURE_CLIENT_ID."
  value       = azuread_application.github_ci.client_id
}

output "azure_tenant_id" {
  description = "Set as repo variable AZURE_TENANT_ID."
  value       = data.azurerm_client_config.current.tenant_id
}

output "azure_subscription_id" {
  description = "Set as repo variable AZURE_SUBSCRIPTION_ID."
  value       = data.azurerm_subscription.current.subscription_id
}
