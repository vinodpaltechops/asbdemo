#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# Bootstrap Script: Set up Azure infrastructure for Terraform state management
# ════════════════════════════════════════════════════════════════════════════
#
# This script creates the foundational infrastructure for managing Terraform
# state in Azure Storage Account instead of HCP Terraform Cloud.
#
# Creates:
#   - Resource group for state infrastructure
#   - Storage account for .tfstate files (with versioning + soft delete)
#   - Key Vault for secrets management
#   - App Registration with GitHub OIDC federated credentials
#   - Role assignments for OIDC access
#
# Usage:
#   bash infra/bootstrap/bootstrap.sh <subscription-id>
#
# Example:
#   bash infra/bootstrap/bootstrap.sh xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
#
# ════════════════════════════════════════════════════════════════════════════

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SUBSCRIPTION_ID="${1}"
LOCATION="southindia"
LOCATION_SHORT="sin"
APP_NAME="asbdemo"

# Resource names
RG_NAME="rg-${APP_NAME}-tfstate-${LOCATION_SHORT}"
STORAGE_ACCOUNT="st${APP_NAME}tfstate${LOCATION_SHORT}" # alphanumeric only, 3-24 chars
KEY_VAULT_NAME="kv-${APP_NAME}-${LOCATION_SHORT}"
APP_REGISTRATION_NAME="sp-${APP_NAME}-github"
GITHUB_REPO="vinodpaltechops/asbdemo"

# Check if subscription ID provided
if [ -z "$SUBSCRIPTION_ID" ]; then
  echo -e "${RED}Error: Subscription ID required${NC}"
  echo "Usage: bash infra/bootstrap/bootstrap.sh <subscription-id>"
  exit 1
fi

# # Validate Azure CLI is installed
# if ! command -v az &> /dev/null; then
#   echo -e "${RED}Error: Azure CLI is not installed${NC}"
#   echo "Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
#   exit 1
# fi

echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Terraform State Bootstrap Setup${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Set subscription context
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[1/7]${NC} Setting subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo -e "${GREEN}✓${NC} Working in subscription: $SUBSCRIPTION_ID"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 2. Create resource group for state infrastructure
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[2/7]${NC} Creating resource group: $RG_NAME..."
az group create \
  --name "$RG_NAME" \
  --location "$LOCATION" \
  --tags "app=$APP_NAME" "purpose=terraform-state" "managed_by=bootstrap"
echo -e "${GREEN}✓${NC} Resource group created"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 3. Create storage account for Terraform state
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[3/7]${NC} Creating storage account: $STORAGE_ACCOUNT..."
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --https-only true \
  --access-tier Hot \
  --min-tls-version TLS1_2

# Enable versioning for state file recovery
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --enable-versioning
echo -e "${GREEN}✓${NC} Storage account created with versioning enabled"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 4. Create blob containers for each environment
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[4/7]${NC} Creating blob containers..."

# Create containers (allowed by default)
for env in dev prod hub; do
  az storage container create \
    --name "tfstate-$env" \
    --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login
  echo -e "${GREEN}✓${NC} Container created: tfstate-$env"
done

# Now restrict access with network rules
echo "Applying network security: restricting access to AzureServices only..."
az storage account update \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RG_NAME" \
  --default-action Deny \
  --bypass AzureServices
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 5. Create Key Vault for secrets
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[5/7]${NC} Creating Key Vault: $KEY_VAULT_NAME..."
az keyvault create \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RG_NAME" \
  --location "$LOCATION" \
  --sku standard \
  --enable-rbac-authorization
echo -e "${GREEN}✓${NC} Key Vault created with RBAC authorization"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 6. Store backend configuration in Key Vault
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[6/7]${NC} Storing configuration in Key Vault..."
CURRENT_USER_ID=$(az ad signed-in-user show --query id -o tsv)

# Grant current user Key Vault Secrets Officer role temporarily to set secrets
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee "$CURRENT_USER_ID" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME" \
  || true  # Might already exist

# Wait a moment for RBAC to propagate
sleep 2

# Store secrets
az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "backend-storage-account" \
  --value "$STORAGE_ACCOUNT"
az keyvault secret set \
  --vault-name "$KEY_VAULT_NAME" \
  --name "backend-resource-group" \
  --value "$RG_NAME"
echo -e "${GREEN}✓${NC} Configuration stored in Key Vault"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 7. Create App Registration with federated OIDC credentials for GitHub
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${YELLOW}[7/7]${NC} Creating App Registration for GitHub OIDC..."

# Check if app already exists
APP_OBJECT_ID=$(az ad app list --display-name "$APP_REGISTRATION_NAME" --query "[0].id" -o tsv 2>/dev/null || echo "")

if [ -z "$APP_OBJECT_ID" ]; then
  # Create new app registration
  APP_RESPONSE=$(az ad app create --display-name "$APP_REGISTRATION_NAME")
  APP_ID=$(echo "$APP_RESPONSE" | jq -r '.appId')
  APP_OBJECT_ID=$(echo "$APP_RESPONSE" | jq -r '.id')
  echo -e "${GREEN}✓${NC} App Registration created: $APP_ID"
else
  # Get existing app ID
  APP_ID=$(az ad app show --id "$APP_OBJECT_ID" --query "appId" -o tsv)
  echo -e "${GREEN}✓${NC} Using existing App Registration: $APP_ID"
fi

# Create service principal (if not exists)
SP_ID=$(az ad sp list --filter "appId eq '$APP_ID'" --query "[0].id" -o tsv 2>/dev/null || echo "")
if [ -z "$SP_ID" ]; then
  az ad sp create --id "$APP_ID"
  SP_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv)
  echo -e "${GREEN}✓${NC} Service Principal created"
else
  echo -e "${GREEN}✓${NC} Service Principal already exists"
fi

# Add federated credentials for GitHub
# Credential 1: Main branch (for apply/push to main)
echo "Adding federated credential: main branch..."
CRED_BODY=$(cat <<EOF
{
  "name": "github-main",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_REPO}:ref:refs/heads/main",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions - main branch (apply)"
}
EOF
)

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "$CRED_BODY" \
  || echo -e "${YELLOW}Note:${NC} Federated credential for main may already exist"

# Credential 2: Pull requests (for plan on PRs)
echo "Adding federated credential: pull requests..."
CRED_BODY=$(cat <<EOF
{
  "name": "github-pr",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_REPO}:pull_request",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions - pull requests (plan)"
}
EOF
)

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "$CRED_BODY" \
  || echo -e "${YELLOW}Note:${NC} Federated credential for PR may already exist"

# Credential 3: GitHub environment (for jobs using environments)
echo "Adding federated credential: GitHub environment..."
CRED_BODY=$(cat <<EOF
{
  "name": "github-environment-azure-dev",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:${GITHUB_REPO}:environment:azure-dev",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "GitHub Actions - azure-dev environment"
}
EOF
)

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters "$CRED_BODY" \
  || echo -e "${YELLOW}Note:${NC} Federated credential for environment may already exist"

echo -e "${GREEN}✓${NC} Federated OIDC credentials configured"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 8. Assign RBAC roles to service principal
# ─────────────────────────────────────────────────────────────────────────────
echo "Assigning RBAC roles to Service Principal..."

# Contributor on subscription (for resource management)
az role assignment create \
  --role "Contributor" \
  --assignee "$SP_ID" \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  || echo -e "${YELLOW}Note:${NC} Contributor role already assigned"

# Storage Blob Data Contributor on storage account (for state file access with OIDC)
STORAGE_ACCOUNT_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_ACCOUNT"
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee "$SP_ID" \
  --scope "$STORAGE_ACCOUNT_ID" \
  || echo -e "${YELLOW}Note:${NC} Storage Blob Data Contributor role already assigned"

# Key Vault Secrets Officer on Key Vault (for reading backend config)
KEY_VAULT_ID="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.KeyVault/vaults/$KEY_VAULT_NAME"
az role assignment create \
  --role "Key Vault Secrets Officer" \
  --assignee "$SP_ID" \
  --scope "$KEY_VAULT_ID" \
  || echo -e "${YELLOW}Note:${NC} Key Vault Secrets Officer role already assigned"

echo -e "${GREEN}✓${NC} RBAC roles assigned"
echo ""

# ═════════════════════════════════════════════════════════════════════════════
# SUCCESS - Output configuration for GitHub
# ═════════════════════════════════════════════════════════════════════════════
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Bootstrap Complete!${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Copy these values to GitHub Repository Settings → Secrets → Variables:${NC}"
echo ""
echo "Name: AZURE_CLIENT_ID"
echo "Value: $APP_ID"
echo ""
echo "Name: AZURE_TENANT_ID"
echo "Value: $TENANT_ID"
echo ""
echo "Name: AZURE_SUBSCRIPTION_ID"
echo "Value: $SUBSCRIPTION_ID"
echo ""
echo "Name: AZURE_KEY_VAULT_NAME"
echo "Value: $KEY_VAULT_NAME"
echo ""
echo -e "${YELLOW}Created Resources:${NC}"
echo "  Resource Group:       $RG_NAME"
echo "  Storage Account:      $STORAGE_ACCOUNT"
echo "  Key Vault:            $KEY_VAULT_NAME"
echo "  App Registration:     $APP_REGISTRATION_NAME ($APP_ID)"
echo "  Service Principal:    $SP_ID"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Add the values above to GitHub repository variables"
echo "  2. Create GitHub Environment 'azure-dev' with required reviewers"
echo "  3. Update infra/terragrunt/envs/dev/terragrunt.hcl with new backend config"
echo "  4. Run: cd infra/terragrunt/envs/dev && terragrunt init"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════${NC}"
