# Terraform State Management: Understanding Resource Tracking

## Why Terraform State Doesn't Show Manually Created Resources

### The Core Concept: State is Intent-Based

**Terraform state is NOT a reflection of what exists in Azure.** It's a record of **what Terraform has created and is managing**.

```
┌─────────────────────────────────────────────────────────┐
│ Azure (Actual Infrastructure)                           │
│                                                         │
│ ┌──────────────────────────┐  ┌─────────────────────┐  │
│ │ Resources Created via    │  │ Resources Created   │  │
│ │ Terraform                │  │ Manually in Portal  │  │
│ │ ✅ Storage Account       │  │ ❌ NOT in state     │  │
│ │ ✅ VM                    │  │ ❌ NOT tracked      │  │
│ │ ✅ VNet                  │  │                     │  │
│ │ (All in .tfstate)        │  │ ⚠️ Terraform        │  │
│ │                          │  │ doesn't know about  │  │
│ └──────────────────────────┘  │ them!               │  │
│                                │                     │  │
│                                └─────────────────────┘  │
└─────────────────────────────────────────────────────────┘
        ↑
        │ Only tracked here
        │
    .tfstate file
    (Terraform State)
```

### Why?

Terraform's philosophy: **Infrastructure as Code**

- **Terraform creates**: Resources are defined in `.tf` files → Terraform creates them → State tracks them
- **Manual creation**: Resources created via Azure portal → Terraform has no code for them → Not in state
- **State = Source of Truth for Terraform**: Terraform uses state to know what it owns and can manage

### Example: What Actually Happens

```bash
# Scenario: You manually create a Storage Account in Azure Portal

# Step 1: Resource exists in Azure
$ az storage account list -o table
Name                     ResourceGroup    Location
───────────────────────  ──────────────── ────────
mystorageaccount         my-rg            eastus

# Step 2: Check Terraform State
$ terraform state list
# Output: (empty - no storage account listed)

# Step 3: Try to reference it in Terraform
resource "azurerm_storage_account" "main" {
  name = "mystorageaccount"
  # ... other config
}

# Step 4: Run terraform plan
$ terraform plan
# Error: 'mystorageaccount' is already taken
# Terraform doesn't know it's "yours" - it's untracked

# Step 5: Run terraform destroy (if you had managed it via TF)
$ terraform destroy
# Won't destroy the manual storage account - it's not in state
```

---

## Two Approaches: Import vs. Data Sources

You chose: **Data Sources (Reference Only)**

This is the right choice for resources you don't plan to manage via Terraform. Let me explain both approaches so you understand the trade-off.

### Approach 1: Import (Take Under Management)

**What it does**: Add existing resource to Terraform state and manage it via code

```bash
# Import a manually created storage account
terraform import azurerm_storage_account.imported /subscriptions/<sub-id>/resourceGroups/my-rg/providers/Microsoft.Storage/storageAccounts/mystorageaccount

# Now it's in state and can be managed
terraform state list
# Output: azurerm_storage_account.imported

# You can now manage it with Terraform code
resource "azurerm_storage_account" "imported" {
  name              = "mystorageaccount"
  resource_group_name = azurerm_resource_group.main.name
  location          = azurerm_resource_group.main.location
  account_tier      = "Standard"
  account_replication_type = "LRS"
}

# Changes go through terraform plan/apply
terraform plan  # Shows any config drift
terraform apply # Updates resource
terraform destroy # Would delete the resource
```

**Pros**:
- ✅ Full control via Terraform
- ✅ Consistent with rest of infrastructure
- ✅ Can detect and fix drift
- ✅ Lifecycle management (create/update/delete)

**Cons**:
- ❌ Must write Terraform config to match existing resource
- ❌ Risk of breaking existing resources if config is wrong
- ❌ Must commit to managing it via TF going forward

### Approach 2: Data Sources (Reference Only) ← You chose this

**What it does**: Read-only access to manually created resources without managing them

```hcl
# Reference a manually created storage account
data "azurerm_storage_account" "external" {
  name                = "mystorageaccount"
  resource_group_name = "my-rg"
}

# Use its properties
output "storage_connection_string" {
  value = data.azurerm_storage_account.external.primary_connection_string
}

# Use in other resources
resource "azurerm_app_service" "main" {
  # ...
  app_settings = {
    StorageConnectionString = data.azurerm_storage_account.external.primary_connection_string
  }
}
```

**Pros**:
- ✅ No import needed - works immediately
- ✅ Read-only - can't accidentally modify
- ✅ No state file bloat
- ✅ Perfect for resources owned by someone else

**Cons**:
- ❌ Can't manage changes via Terraform
- ❌ If someone deletes resource in portal, Terraform won't know
- ❌ No drift detection

---

## How to Use Data Sources (Your Choice)

Data sources are blocks that **read** existing Azure resources WITHOUT managing them.

### Common Data Sources for External Resources

```hcl
# 1. Read an existing Resource Group
data "azurerm_resource_group" "external" {
  name = "my-external-rg"
}

output "rg_location" {
  value = data.azurerm_resource_group.external.location
}

# 2. Read an existing Storage Account
data "azurerm_storage_account" "external" {
  name                = "mystorageaccount"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "storage_id" {
  value = data.azurerm_storage_account.external.id
}

# 3. Read an existing Virtual Network
data "azurerm_virtual_network" "external" {
  name                = "external-vnet"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "vnet_subnets" {
  value = data.azurerm_virtual_network.external.subnets
}

# 4. Read an existing Subnet
data "azurerm_subnet" "external" {
  name                 = "external-subnet"
  virtual_network_name = data.azurerm_virtual_network.external.name
  resource_group_name  = data.azurerm_resource_group.external.name
}

output "subnet_id" {
  value = data.azurerm_subnet.external.id
}

# 5. Read an existing Storage Account Container
data "azurerm_storage_container" "external" {
  name                  = "my-container"
  storage_account_name  = data.azurerm_storage_account.external.name
}

output "container_id" {
  value = data.azurerm_storage_container.external.id
}

# 6. Read an existing Database (SQL Server)
data "azurerm_mssql_server" "external" {
  name                = "external-sql-server"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "sql_server_fqdn" {
  value = data.azurerm_mssql_server.external.fully_qualified_domain_name
}

# 7. Read an existing Database (within SQL Server)
data "azurerm_mssql_database" "external" {
  name       = "external-database"
  server_id  = data.azurerm_mssql_server.external.id
}

output "database_id" {
  value = data.azurerm_mssql_database.external.id
}

# 8. Read an existing App Service
data "azurerm_app_service" "external" {
  name                = "external-webapp"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "app_service_url" {
  value = data.azurerm_app_service.external.default_site_hostname
}

# 9. Read an existing VM
data "azurerm_virtual_machine" "external" {
  name                = "external-vm"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "vm_id" {
  value = data.azurerm_virtual_machine.external.id
}

# 10. Read an existing NSG
data "azurerm_network_security_group" "external" {
  name                = "external-nsg"
  resource_group_name = data.azurerm_resource_group.external.name
}

output "nsg_id" {
  value = data.azurerm_network_security_group.external.id
}
```

---

## Practical Example: Mix Terraform-Managed + External Resources

Let's say:
- **Resource Group** → Manually created in portal (external)
- **VNet** → Manually created in portal (external)
- **App Service** → Terraform manages (our code)
- Want App Service to use connection string from external Storage Account

```hcl
# Reference external resources (no management)
data "azurerm_resource_group" "external" {
  name = "my-external-rg"
}

data "azurerm_storage_account" "external" {
  name                = "externalstorage"
  resource_group_name = data.azurerm_resource_group.external.name
}

# Create a resource we manage with Terraform
resource "azurerm_service_plan" "main" {
  name                = "asbdemo-app-plan"
  location            = data.azurerm_resource_group.external.location
  resource_group_name = data.azurerm_resource_group.external.name
  
  os_type  = "Linux"
  sku_name = "B1"
}

resource "azurerm_linux_web_app" "main" {
  name                = "asbdemo-webapp"
  location            = data.azurerm_resource_group.external.location
  resource_group_name = data.azurerm_resource_group.external.name
  service_plan_id     = azurerm_service_plan.main.id

  app_settings = {
    # Use external storage account connection string
    STORAGE_CONNECTION_STRING = data.azurerm_storage_account.external.primary_connection_string
    ENVIRONMENT = "production"
  }

  site_config {
    application_stack {
      node_version = "18-lts"
    }
  }
}

# Outputs for reference
output "app_service_url" {
  value = azurerm_linux_web_app.main.default_hostname
}

output "external_storage_name" {
  value = data.azurerm_storage_account.external.name
}
```

---

## Step-by-Step: How to Add Data Sources to Your Config

### Step 1: Identify the External Resources

List all resources you created manually:
```bash
# Check what exists in Azure
az resource list --resource-group my-external-rg -o table

# Example output:
# Name                  Type                              Location
# ────────────────────  ──────────────────────────────    ────────
# external-storage      Microsoft.Storage/storageAccounts eastus
# external-vnet         Microsoft.Network/virtualNetworks eastus
# external-vm           Microsoft.Compute/virtualMachines eastus
```

### Step 2: Create Data Source Blocks

Create a new file: `infra/terraform/envs/shared/external_resources.tf`

```hcl
# External resources reference (not managed by Terraform)

data "azurerm_resource_group" "external" {
  name = var.external_resource_group_name
}

data "azurerm_storage_account" "external" {
  count               = var.external_storage_account_name != "" ? 1 : 0
  name                = var.external_storage_account_name
  resource_group_name = data.azurerm_resource_group.external.name
}

data "azurerm_virtual_network" "external" {
  count               = var.external_vnet_name != "" ? 1 : 0
  name                = var.external_vnet_name
  resource_group_name = data.azurerm_resource_group.external.name
}

data "azurerm_subnet" "external" {
  count                = var.external_subnet_name != "" ? 1 : 0
  name                 = var.external_subnet_name
  virtual_network_name = data.azurerm_virtual_network.external[0].name
  resource_group_name  = data.azurerm_resource_group.external.name
}
```

### Step 3: Add Variables for External Resources

Add to `infra/terraform/envs/shared/variables.tf`:

```hcl
variable "external_resource_group_name" {
  description = "Name of external resource group (not managed by Terraform)"
  type        = string
  default     = ""
}

variable "external_storage_account_name" {
  description = "Name of external storage account (not managed by Terraform)"
  type        = string
  default     = ""
}

variable "external_vnet_name" {
  description = "Name of external VNet (not managed by Terraform)"
  type        = string
  default     = ""
}

variable "external_subnet_name" {
  description = "Name of external subnet (not managed by Terraform)"
  type        = string
  default     = ""
}
```

### Step 4: Pass Values via Terragrunt

In `infra/terragrunt/envs/dev/terragrunt.hcl`:

```hcl
inputs = {
  environment              = "dev"
  # ... existing inputs ...
  
  # External resources
  external_resource_group_name  = "my-external-rg"
  external_storage_account_name = "externalstorage"
  external_vnet_name            = "external-vnet"
  external_subnet_name          = "external-subnet"
}
```

### Step 5: Use External Resources in Your Code

Now you can reference them:

```hcl
# In any resource that needs external resource properties
resource "azurerm_app_service" "main" {
  app_settings = {
    EXTERNAL_STORAGE_CONNECTION = data.azurerm_storage_account.external[0].primary_connection_string
    EXTERNAL_VNET_ID            = data.azurerm_virtual_network.external[0].id
  }
}

# Export for reference
output "external_storage_connection_string" {
  value       = try(data.azurerm_storage_account.external[0].primary_connection_string, "")
  sensitive   = true
  description = "Connection string from external storage account"
}
```

---

## Terraform State Explanation

### What IS in State?

```bash
$ terraform state list
azurerm_resource_group.main
azurerm_virtual_network.main
azurerm_kubernetes_cluster.main
module.aks.azurerm_kubernetes_cluster.main
# ... all resources Terraform created
```

### What's NOT in State?

- Resources created manually in Azure portal
- Resources created by other tools
- Resources created by other Terraform workspaces
- Resources in data blocks (data sources)

### State File Location

```bash
# Local (not recommended for production)
terraform.tfstate  # in your working directory

# Remote (HCP Terraform - you're using this)
# Stored in: HCP Terraform workspace "azure-dev"
# Access via: terraform state list, terraform state show

# Check current state
terraform state list   # List all managed resources
terraform state show   # Show details of a resource
terraform state pull   # Download state JSON (dangerous!)
```

---

## Common Scenarios & Solutions

### Scenario 1: Reference External RG + Create Resources in It

```hcl
# Read external RG
data "azurerm_resource_group" "external" {
  name = "external-rg"
}

# Create resources in that RG
resource "azurerm_storage_account" "managed" {
  name                = "managedstorage"
  resource_group_name = data.azurerm_resource_group.external.name  # Use external RG
  location            = data.azurerm_resource_group.external.location
  account_tier        = "Standard"
  account_replication_type = "LRS"
}
```

### Scenario 2: Link Terraform-Managed App to External Database

```hcl
# Reference external database
data "azurerm_mssql_server" "external_db" {
  name                = "external-sqlserver"
  resource_group_name = "external-rg"
}

data "azurerm_mssql_database" "external_db" {
  name       = "external-database"
  server_id  = data.azurerm_mssql_server.external_db.id
}

# Create app that uses it
resource "azurerm_linux_web_app" "main" {
  name                = "asbdemo-app"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.main.id

  connection_strings {
    name             = "DefaultConnection"
    type             = "SQLAzure"
    connection_string = "Server=tcp:${data.azurerm_mssql_server.external_db.fully_qualified_domain_name},...;Database=${data.azurerm_mssql_database.external_db.name};..."
  }
}
```

### Scenario 3: Share Outputs from External Resources

```hcl
# External resource
data "azurerm_storage_account" "external" {
  name                = "externalstorage"
  resource_group_name = "external-rg"
}

# Export its properties so other projects can use them
output "external_storage_connection_string" {
  value       = data.azurerm_storage_account.external.primary_connection_string
  sensitive   = true
  description = "Connection string from external storage (for sharing with other projects)"
}

output "external_storage_id" {
  value       = data.azurerm_storage_account.external.id
  description = "Resource ID of external storage account"
}
```

---

## Verify Your Data Sources Work

```bash
# Check if data source can be read (before apply)
terraform plan

# Should show: Refresh state for data sources
# Data sources are always "read" fresh, never stored in state

# If error: "data source not found"
# ├─ Check resource name is correct
# ├─ Check resource group name is correct
# └─ Check you have permissions to read the resource

# View data source values (after apply)
terraform state show data.azurerm_resource_group.external
# Output:
# resource "azurerm_resource_group" "external" {
#   location = "eastus"
#   name     = "my-external-rg"
#   # ... other properties
# }
```

---

## Best Practices

1. **Use Data Sources for External Resources**: Don't import if you don't manage them
2. **Document Dependencies**: Comment in code that resources depend on external infrastructure
3. **Validate Existence**: Run `terraform plan` early to catch missing external resources
4. **Use Sensible Defaults**: Set `default = ""` for optional external resource variables
5. **Export What Matters**: Create outputs for properties other projects might need
6. **Version Control Your Code**: Commit `.tf` files with data sources, don't commit `.tfstate`

---

## Summary

| Aspect | Managed (Import) | External (Data Source) |
|--------|---|---|
| State tracking | ✅ In state | ❌ Not in state |
| Creation | Terraform creates | Manual/Other tool |
| Modification | `terraform apply` | Not possible |
| Deletion | `terraform destroy` | Not tracked |
| When to use | You own the resource | Someone else owns it |
| Your choice | ❌ | ✅ (what you chose) |

**Your approach is correct**: Use data sources to reference the manually created resources without trying to manage them via Terraform.
