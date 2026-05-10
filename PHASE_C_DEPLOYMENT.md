# Phase C Deployment Guide: Azure-Native State + Full Deployment

**Status:** ✅ All code changes complete. Ready for deployment to new Azure free-tier account.

---

## What Changed

- **State Management:** HCP Terraform Cloud → Azure Storage Account (blob backend)
- **Authentication:** Service Principal secrets → GitHub OIDC (federated identity, no secrets)
- **Secrets Management:** GitHub secrets → Azure Key Vault
- **Deployment:** Single broken terraform.yml → New 3-job workflow with Terragrunt
- **Policy Enforcement:** OPA policies now work with OIDC auth

**No code duplication, full end-to-end automation from bootstrap → deploy.**

---

## Prerequisites

✅ New Azure free-tier account (you have this)
✅ Azure CLI installed (`az --version`)
✅ Git access to repo
✅ GitHub admin access to configure variables + environments

---

## Step 1: Bootstrap Infrastructure (5 min)

Run **once** to create the state storage account + Key Vault + service principal.

### Command

```bash
bash infra/bootstrap/bootstrap.sh <your-subscription-id>
```

**Example:**
```bash
bash infra/bootstrap/bootstrap.sh xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### What It Does

- Creates resource group: `rg-asbdemo-tfstate-sin`
- Creates storage account: `stasbdtfstatesin` (versioning + soft delete enabled)
- Creates Key Vault: `kv-asbdemo-sin`
- Creates App Registration: `sp-asbdemo-github` with GitHub OIDC federated credentials
- Assigns RBAC roles (Contributor, Storage Blob Data Contributor, Key Vault Secrets Officer)
- Outputs 4 values you'll use in Step 2

### Output

The script prints:
```
Name: AZURE_CLIENT_ID
Value: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Name: AZURE_TENANT_ID
Value: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Name: AZURE_SUBSCRIPTION_ID
Value: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

Name: AZURE_KEY_VAULT_NAME
Value: kv-asbdemo-sin
```

**Copy these 4 values.** You'll use them in Step 2.

---

## Step 2: Configure GitHub (5 min)

### Add Repository Variables

Go to: **Repository Settings → Secrets and variables → Variables**

Add **4 variables** (NOT secrets):

| Name | Value |
|------|-------|
| `AZURE_CLIENT_ID` | From bootstrap output |
| `AZURE_TENANT_ID` | From bootstrap output |
| `AZURE_SUBSCRIPTION_ID` | From bootstrap output |
| `AZURE_KEY_VAULT_NAME` | `kv-asbdemo-sin` |

### Create GitHub Environment

Go to: **Repository Settings → Environments → New environment**

Create environment named: `azure-dev`

**Optional:** Add required reviewers for apply gate (who must approve before infra is created)

---

## Step 3: Deploy Infrastructure (varies by resource count)

### Option A: Deploy via PR + Push (Recommended)

```bash
# 1. Create branch with a test infra change
git checkout -b test/terraform-workflow

# 2. Make a minor edit (e.g., add a tag to a resource)
# OR just commit the existing changes (they're already ready)

git push origin test/terraform-workflow
```

### Watch the Workflow

1. **Go to:**  GitHub Repo → Actions → Terraform workflow
2. **PR stage:**
   - Opens PR → terraform.yml runs automatically
   - See: validate ✓ → plan ✓ → outputs resource details as PR comment
3. **Merge & Deploy:**
   - Merge to main → apply job triggers
   - Requires approval from `azure-dev` environment (if configured)
   - Workflow creates all infrastructure in Azure

### What Gets Created

- Resource Group: `rg-asbdemo-dev-sin`
- AKS cluster: `aks-asbdemo-dev-sin`
- Virtual Network: `vnet-asbdemo-dev-sin` (10.40.0.0/16)
- Service Bus: `sb-asbdemo-dev-sin-XXXXX`
- Container Registry: `acrascbdemodevsin`
- Key Vault: `kv-asbdemo-dev-sin`
- Log Analytics: `log-asbdemo-dev-sin`
- 2 Workload Identities: `mi-orders-*`, `mi-payments-*`

**Time estimate:** 15-20 minutes (AKS creation is slow)

### Option B: Deploy Manually (Offline Testing)

If you want to test locally before pushing:

```bash
# 1. Set your Azure subscription as default
az account set --subscription <subscription-id>

# 2. Login to Azure (creates credentials for local terraform)
az login

# 3. Navigate to dev environment
cd infra/terragrunt/envs/dev

# 4. Initialize Terraform (connects to Azure blob backend)
terragrunt init

# 5. Plan (shows what will be created)
terragrunt plan

# 6. Apply (creates resources - will prompt for confirmation)
terragrunt apply
```

---

## Step 4: Get Infrastructure Outputs

Once deployment completes, retrieve the infrastructure details:

```bash
cd infra/terragrunt/envs/dev

# Get all outputs
terragrunt output

# Outputs include:
# - aks_name: AKS cluster name
# - aks_oidc_issuer_url: For workload identity
# - acr_login_server: Container registry address
# - key_vault_uri: Key Vault endpoint
# - servicebus_namespace: Service Bus namespace
# - workload_identities: Client IDs for Spring Boot services
```

---

## Step 5: Configure AKS Access (Optional - for manual operations)

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group rg-asbdemo-dev-sin \
  --name aks-asbdemo-dev-sin \
  --overwrite-existing

# Verify access
kubectl get nodes
```

---

## Step 6: Deploy Applications (After Infra Ready)

Once AKS is running:

### Option A: Via GitOps (Recommended)

1. Push app changes to `app/` folder
2. GitHub workflow (`app-ci.yml`) builds images
3. ArgoCD (manual install) syncs from `gitops/` repo
4. Apps auto-deployed on every image push

### Option B: Manual via Helm/Kubectl

```bash
# See gitops/bootstrap/argocd/install.sh for full setup
# Or deploy services directly with kubectl
```

---

## Troubleshooting

### Bootstrap Script Fails

```bash
# Error: "ResourceNotFound" when creating container
# Solution: Check Azure CLI is authenticated
az account show  # Should show your subscription

# Error: "Permission denied" on role assignment
# Solution: You need Owner role in subscription
az role assignment list --query "[?scope=='<subscription-id>'].roleDefinitionName"
```

### Terraform Plan Fails with "Backend Error"

```bash
# Error: "Failed to authenticate with service principal"
# Solution: Verify GitHub variables are set correctly
# Go to: Settings → Secrets and variables → Variables
# Check: AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID

# Or test locally:
export ARM_CLIENT_ID=<from-bootstrap>
export ARM_TENANT_ID=<from-bootstrap>
export ARM_SUBSCRIPTION_ID=<from-bootstrap>
export ARM_USE_OIDC=true
cd infra/terragrunt/envs/dev && terragrunt plan
```

### Workflow Stuck on "Apply" Requiring Approval

This is expected if you configured `azure-dev` environment with required reviewers.

**To approve:**
1. Go to: Actions → Terraform → Deployment review
2. Click "Review deployments"
3. Select "azure-dev"
4. Approve

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ GitHub Actions Workflow                                     │
│ (terraform.yml - triggered by PR/push)                      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ├─ OIDC Token (federated identity)
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ Azure Service Principal (sp-asbdemo-github)                 │
│ ├─ Contributor on subscription                              │
│ ├─ Storage Blob Data Contributor on state storage account   │
│ └─ Key Vault Secrets Officer on Key Vault                   │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ├──────────────────────┬──────────────────┐
                   │                      │                  │
        ┌──────────▼────────┐  ┌─────────▼──────┐  ┌────────▼────┐
        │ Storage Account   │  │ Key Vault      │  │ Azure       │
        │ (tfstate-dev)     │  │ (Secrets)      │  │ Resources   │
        │ - versioning      │  │ - backend-*    │  │ - AKS       │
        │ - soft delete     │  │ - app secrets  │  │ - Network   │
        └───────────────────┘  └────────────────┘  │ - Service   │
                                                   │   Bus       │
                                                   │ - Key Vault │
                                                   │ - ACR, etc. │
                                                   └─────────────┘
```

---

## Files Changed Summary

### Created
- `infra/bootstrap/bootstrap.sh` — One-time setup script
- `.github/workflows/terraform.yml` — Complete rewrite (validate → plan → apply)

### Modified
- `infra/terragrunt/env.hcl` — Added backend_rg, backend_sa locals
- `infra/terragrunt/root.hcl` — Added use_oidc=true to providers
- `infra/terragrunt/envs/dev/terragrunt.hcl` — Replaced HCP backend with Azure blob backend
- `infra/terraform/envs/azure-hub/versions.tf` — Removed hardcoded HCP cloud block
- `.github/workflows/terraform-policy.yml` — Replaced TF_API_TOKEN with OIDC auth

### No Changes Needed
- Infrastructure code (modules, shared, azure-hub main.tf)
- App CI/CD (app-ci.yml already uses OIDC)
- OPA policies (work with OIDC)

---

## What's Next

### After Dev is Running

1. **Prod/Hub:** Add them by updating terragrunt.hcl files similarly
2. **App Deployment:** Install ArgoCD and deploy Spring Boot services
3. **CI/CD:** App images auto-build and deploy on every push
4. **Monitoring:** View logs in Azure Log Analytics

### Long-Term

- Monitor costs (free tier has limits)
- Enable backups for AKS persistent volumes
- Add more policies (Sentinel, cost controls)
- Scale to multi-region setup

---

## Support

**Stuck?** Check these files:
- `infra/.conftest/PHASE_B_SUMMARY.md` — Phase B overview
- `.github/workflows/terraform.yml` — Workflow logic (well-commented)
- `infra/terragrunt/envs/dev/terragrunt.hcl` — Terraform backend config
- `docs/TERRAFORM_STATE_MANAGEMENT.md` — State management concepts
- `docs/TERRAFORM_IMPORT_GUIDE.md` — How to import existing resources

---

## Quick Checklist

- [ ] Run bootstrap script
- [ ] Copy 4 values to GitHub Variables
- [ ] Create `azure-dev` GitHub Environment
- [ ] Create a PR with infra changes (or push to feature branch)
- [ ] Approve apply in `azure-dev` environment
- [ ] Check Azure Portal for created resources
- [ ] Run `terragrunt output` to get infrastructure endpoints

**Estimated time:** 30 minutes (including 15-20 min AKS creation)

---

**Go!** 🚀 Run the bootstrap script and watch your infrastructure deploy automatically.
