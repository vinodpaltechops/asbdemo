# Terraform Import Guide: Taking External Resources Under Management

This guide explains how to import manually created Azure resources into Terraform state and manage them via code.

## When to Import vs. Use Data Sources

| Scenario | Use Import | Use Data Sources |
|---|---|---|
| You want to **manage** the resource via Terraform | ✅ Yes | ❌ No |
| You want to **read** from an external resource | ❌ No | ✅ Yes |
| You own the resource | ✅ Yes | ✅ Either |
| Someone else owns the resource | ❌ No | ✅ Yes |
| You want to control creation/updates/deletion | ✅ Yes | ❌ No |
| You want read-only access (safer) | ❌ No | ✅ Yes |

---

## Import Process Overview

```
┌─────────────────────────────────────────────┐
│ External Resource in Azure                   │
│ (Created via Portal, CLI, or other tool)     │
│                                              │
│ Example: Storage Account "myexternalstorage" │
└────────────────────┬────────────────────────┘
                     │
                     ↓ (Step 1: Get Resource ID)
                 /subscriptions/.../storageAccounts/myexternalstorage
                     │
                     ↓ (Step 2: Write Terraform block)
┌─────────────────────────────────────────────┐
│ resource "azurerm_storage_account" "import" │
│   name = "myexternalstorage"                 │
│   ...config...                               │
│ }                                            │
└────────────────────┬────────────────────────┘
                     │
                     ↓ (Step 3: terraform import)
        terraform import <resource_id>
                     │
                     ↓ (Step 4: State updated)
┌─────────────────────────────────────────────┐
│ .tfstate file now contains:                 │
│   azurerm_storage_account.import             │
│                                              │
│ Now Terraform manages the resource!          │
└─────────────────────────────────────────────┘
```

---

## Step-by-Step: Import a Storage Account

This is the most common pattern. Adapt for other resource types.

### Step 1: Identify Your Resource

List all external resources:
```bash
# List all storage accounts in Azure
az storage account list --query "[].{name: name, rg: resourceGroup}" -o table

# Output:
# Name                   ResourceGroup
# ─────────────────────  ──────────────────
# myexternalstorage      my-external-rg
```

### Step 2: Get the Azure Resource ID

**Option A: Azure Portal**
1. Go to the resource
2. Click "JSON View" (bottom right)
3. Copy the `id` field

**Option B: Azure CLI**
```bash
az storage account show \
  --name myexternalstorage \
  --resource-group my-external-rg \
  --query id -o tsv

# Output:
# /subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage
```

Save this ID — you'll need it for the import command.

### Step 3: Write the Terraform Resource Block

Add this to `infra/terraform/envs/shared/main.tf`:

```hcl
# Imported external storage account (originally created manually)
resource "azurerm_storage_account" "imported_external" {
  name                     = "myexternalstorage"
  resource_group_name      = "my-external-rg"
  location                 = "southindia"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  https_traffic_only_enabled = true

  tags = local.tags
}
```

**Important:** Your Terraform config must match the actual Azure resource config. Get the values from Azure Portal or CLI:

```bash
az storage account show \
  --name myexternalstorage \
  --resource-group my-external-rg \
  -o table

# Check each property and include in your Terraform block
```

### Step 4: Import the Resource

```bash
cd infra/terragrunt/envs/dev

# Run the import command
terragrunt import 'azurerm_storage_account.imported_external' \
  '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage'
```

**Expected output:**
```
azurerm_storage_account.imported_external: Importing from ID "/subscriptions/.../storageAccounts/myexternalstorage"...
azurerm_storage_account.imported_external: Import successful!

Apply complete! Resources: 1 added.
```

### Step 5: Verify Import Success

```bash
# Check state
terragrunt state list
# Output should include:
# azurerm_storage_account.imported_external

# Show resource details
terragrunt state show azurerm_storage_account.imported_external
# Should display all properties from Azure
```

### Step 6: Verify Plan Shows No Changes

```bash
terragrunt plan
```

**Expected output:**
```
No changes. Your infrastructure matches the configuration.
```

If you see changes, your Terraform config doesn't match Azure reality. Fix the config:
```bash
# Example: If you forgot to set https_traffic_only_enabled
terragrunt plan
# Output: https_traffic_only_enabled: false → true

# Fix in Terraform
resource "azurerm_storage_account" "imported_external" {
  https_traffic_only_enabled = true  # ← Add this
}

terragrunt plan
# Now: No changes
```

### Step 7: Now It's Managed!

You can now:

```bash
# Update the resource via Terraform
# (Edit the resource block and run apply)
terragrunt apply

# Destroy the resource via Terraform
terragrunt destroy

# Reference it in other resources
data "azurerm_storage_account" "app_storage" {
  name                = azurerm_storage_account.imported_external.name
  resource_group_name = azurerm_storage_account.imported_external.resource_group_name
}

# Track drift
terragrunt plan  # Shows any manual changes in Azure
```

---

## Import Common Azure Resources

### Resource Group

```bash
# Terraform block
resource "azurerm_resource_group" "imported" {
  name     = "my-external-rg"
  location = "southindia"
  tags     = local.tags
}

# Get ID
az group show --name my-external-rg --query id -o tsv
# /subscriptions/xxx/resourceGroups/my-external-rg

# Import
terragrunt import azurerm_resource_group.imported \
  '/subscriptions/xxx/resourceGroups/my-external-rg'
```

### Virtual Network

```bash
# Terraform block
resource "azurerm_virtual_network" "imported" {
  name                = "external-vnet"
  resource_group_name = "my-external-rg"
  location            = "southindia"
  address_space       = ["10.0.0.0/16"]
}

# Get ID
az network vnet show \
  --name external-vnet \
  --resource-group my-external-rg \
  --query id -o tsv

# Import
terragrunt import azurerm_virtual_network.imported \
  '/subscriptions/xxx/resourceGroups/my-external-rg/providers/Microsoft.Network/virtualNetworks/external-vnet'
```

### SQL Server

```bash
# Terraform block
resource "azurerm_mssql_server" "imported" {
  name                         = "my-sql-server"
  resource_group_name          = "my-external-rg"
  location                     = "southindia"
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "P@ssw0rd1234!"
}

# Get ID
az sql server show \
  --name my-sql-server \
  --resource-group my-external-rg \
  --query id -o tsv

# Import
terragrunt import azurerm_mssql_server.imported \
  '/subscriptions/xxx/resourceGroups/my-external-rg/providers/Microsoft.Sql/servers/my-sql-server'
```

### Key Vault

```bash
# Terraform block
resource "azurerm_key_vault" "imported" {
  name                       = "my-external-vault"
  location                   = "southindia"
  resource_group_name        = "my-external-rg"
  enabled_for_disk_encryption = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
}

# Get ID
az keyvault show --name my-external-vault --query id -o tsv

# Import
terragrunt import azurerm_key_vault.imported \
  '/subscriptions/xxx/resourceGroups/my-external-rg/providers/Microsoft.KeyVault/vaults/my-external-vault'
```

### Virtual Machine

```bash
# Terraform block
resource "azurerm_virtual_machine" "imported" {
  name                  = "external-vm"
  location              = "southindia"
  resource_group_name   = "my-external-rg"
  vm_size               = "Standard_B2s"
}

# Get ID
az vm show --name external-vm --resource-group my-external-rg --query id -o tsv

# Import
terragrunt import azurerm_virtual_machine.imported \
  '/subscriptions/xxx/resourceGroups/my-external-rg/providers/Microsoft.Compute/virtualMachines/external-vm'
```

---

## Troubleshooting

### Problem: "ResourceNotFound"

**Cause:** Resource doesn't exist or ID is wrong

**Solution:**
```bash
# Verify resource exists
az resource show --id "/your/resource/id"

# If it doesn't exist, create it manually first
# If it exists, check that the ID format is exactly correct
```

### Problem: "Already exists in state"

**Cause:** Resource already imported, trying to import again

**Solution:**
```bash
# Remove from state first
terragrunt state rm azurerm_storage_account.imported_external

# Then import again
terragrunt import azurerm_storage_account.imported_external <id>
```

### Problem: Plan shows changes after import

**Cause:** Terraform config doesn't match Azure reality

**Solution:**
```bash
# See what's different
terragrunt plan

# Example output:
# ~ resource "azurerm_storage_account" "imported_external" {
#     ~ https_traffic_only_enabled = false -> true

# Update your Terraform config to match Azure
resource "azurerm_storage_account" "imported_external" {
  https_traffic_only_enabled = false  # ← Match what exists in Azure
}

# Verify
terragrunt plan
# Now: No changes
```

### Problem: "Unsupported resource type"

**Cause:** Azure resource doesn't support Terraform import

**Solution:**
- Use a data source instead for read-only access
- Check Terraform Azure provider docs: https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs

### Problem: "Invalid attribute value"

**Cause:** Required property is missing from Terraform config

**Solution:**
```bash
# Get actual properties from Azure
az storage account show --name myexternalstorage --resource-group my-external-rg

# Copy all properties into your Terraform block
# Common required properties:
# - account_tier (Standard/Premium)
# - account_replication_type (LRS/GRS/RAGRS/ZRS)
# - https_traffic_only_enabled (true/false)
```

---

## Import Workflow Example

```bash
# 1. List what you have in Azure
az storage account list --query "[].name" -o tsv
# myexternalstorage

# 2. Get its resource ID
RESOURCE_ID=$(az storage account show \
  --name myexternalstorage \
  --resource-group my-external-rg \
  --query id -o tsv)

echo $RESOURCE_ID
# /subscriptions/xxx/resourceGroups/my-external-rg/providers/Microsoft.Storage/storageAccounts/myexternalstorage

# 3. Add Terraform block
cat >> infra/terraform/envs/shared/main.tf << 'EOF'
resource "azurerm_storage_account" "imported_external" {
  name                     = "myexternalstorage"
  resource_group_name      = "my-external-rg"
  location                 = "southindia"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.tags
}
EOF

# 4. Import
cd infra/terragrunt/envs/dev
terragrunt import azurerm_storage_account.imported_external "$RESOURCE_ID"

# 5. Verify
terragrunt state list
terragrunt plan
# Expected: No changes

# 6. Commit
git add . && git commit -m "import: Add external storage account under Terraform management"

# 7. Now it's managed - you can update/delete via Terraform
terragrunt apply
terragrunt destroy
```

---

## Best Practices

1. **Import one resource at a time** — Easier to debug
2. **Verify plan shows no changes** — Indicates config matches Azure reality
3. **Document why it was imported** — Add a comment in the code
4. **Test updates before going to prod** — Change something minor and apply to verify it works
5. **Use same naming for imported resources** — Makes it clear they're imported: `.imported_*`
6. **Consider starting with data sources** — Safer than managing someone else's resources

---

## Comparison: Import vs. Data Sources

```hcl
# OPTION 1: Import (Full Management)
resource "azurerm_storage_account" "imported" {
  name                     = "myexternalstorage"
  resource_group_name      = "my-external-rg"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Usage:
# ✅ Can update: Change account_replication_type to GRS → apply
# ✅ Can delete: terraform destroy
# ✅ Can reference: azurerm_storage_account.imported.id
# ❌ Must manage: Updates/drift must be handled in Terraform

# ─────────────────────────────────────────────────────────

# OPTION 2: Data Source (Read-Only)
data "azurerm_storage_account" "external" {
  name                = "myexternalstorage"
  resource_group_name = "my-external-rg"
}

# Usage:
# ✅ Can read: data.azurerm_storage_account.external.id
# ✅ Safe: Can't accidentally modify
# ✅ No state: Doesn't track resource
# ❌ Can't manage: Can't update or delete via Terraform
```

---

## Next Steps

1. **List your external resources** — What did you create manually?
2. **Choose import or data source** — See table at top
3. **Get resource IDs** — Use Azure CLI or Portal
4. **Write Terraform blocks** — Add to main.tf
5. **Import** — Run terraform import
6. **Verify** — Check state and plan
7. **Commit** — Add to git

---

## Related Documentation

- [TERRAFORM_STATE_MANAGEMENT.md](TERRAFORM_STATE_MANAGEMENT.md) — Why state doesn't track manual resources
- [main.tf](../infra/terraform/envs/shared/main.tf) — Example import documentation in code
- [Terraform Azure Provider Docs](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs) — Official resource docs
