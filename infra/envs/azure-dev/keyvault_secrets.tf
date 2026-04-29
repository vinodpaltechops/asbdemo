# Secret slots used by the Azure DevOps pipelines.
#
# Terraform creates the secret resource so the ADO Key Vault task can resolve
# the name. Initial value is a placeholder; the real value is set out-of-band
# (`az keyvault secret set ...` or the portal) and Terraform ignores rotations
# via `lifecycle.ignore_changes`.

# So Terraform itself can write secrets here on first apply.
resource "azurerm_role_assignment" "tf_runner_kv_secrets_officer" {
  scope                = module.keyvault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# HCP Terraform user/team token — used by the terraform-pipeline.yml.
resource "azurerm_key_vault_secret" "tf_api_token" {
  name         = "tf-api-token"
  key_vault_id = module.keyvault.id
  value        = "REPLACE_ME"
  content_type = "HCP Terraform API token (set via az keyvault secret set)"

  depends_on = [azurerm_role_assignment.tf_runner_kv_secrets_officer]

  lifecycle {
    ignore_changes = [value, tags]
  }
}

# GitHub PAT used by the app pipeline to push the GitOps kustomization bump
# back to the repo. Needs `contents:write` on the asbdemo repo.
resource "azurerm_key_vault_secret" "github_pat_gitops" {
  name         = "github-pat-gitops"
  key_vault_id = module.keyvault.id
  value        = "REPLACE_ME"
  content_type = "GitHub PAT (contents:write) for GitOps bump"

  depends_on = [azurerm_role_assignment.tf_runner_kv_secrets_officer]

  lifecycle {
    ignore_changes = [value, tags]
  }
}
