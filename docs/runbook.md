# Runbook

Operational procedures for the `asbdemo` project. Run phases in order the first time.

---

## Phase 1 — Azure OIDC federation for HCP Terraform (one-time, manual)

**Goal:** let HCP Terraform workspace `vinod-techops-org/azure-dev` assume an Azure identity at runtime using short-lived OIDC tokens — no client secrets stored anywhere.

### 1.1 Prerequisites

```sh
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>

# Capture IDs we'll reuse
export SUB_ID=$(az account show --query id -o tsv)
export TENANT_ID=$(az account show --query tenantId -o tsv)

echo "SUB_ID=$SUB_ID"
echo "TENANT_ID=$TENANT_ID"
```

### 1.2 Create Azure AD app registration + service principal

```sh
# Create the app registration
APP_ID=$(az ad app create \
  --display-name terraform-ci \
  --query appId -o tsv)

echo "APP_ID=$APP_ID"

# Create the matching service principal
az ad sp create --id "$APP_ID"
```

### 1.3 Grant RBAC at subscription scope

`Contributor` lets the SP create/manage Azure resources. `User Access Administrator` is required later to grant AKS → ACR pull and workload identity role assignments.

```sh
az role assignment create \
  --assignee "$APP_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUB_ID"

az role assignment create \
  --assignee "$APP_ID" \
  --role "User Access Administrator" \
  --scope "/subscriptions/$SUB_ID"
```

### 1.4 Add federated credentials (HCP workspace → Azure)

HCP Terraform issues an OIDC token per run, with a `sub` claim like
`organization:<org>:project:<project>:workspace:<workspace>:run_phase:<plan|apply>`.

We register **two** federated credentials on the app — one for `plan`, one for `apply`:

```sh
# Credential for PLAN runs
cat > /tmp/fedcred-plan.json <<EOF
{
  "name": "hcp-azure-dev-plan",
  "issuer": "https://app.terraform.io",
  "subject": "organization:vinod-techops-org:project:Default Project:workspace:azure-dev:run_phase:plan",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "HCP Terraform azure-dev workspace, plan phase"
}
EOF

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters /tmp/fedcred-plan.json

# Credential for APPLY runs
cat > /tmp/fedcred-apply.json <<EOF
{
  "name": "hcp-azure-dev-apply",
  "issuer": "https://app.terraform.io",
  "subject": "organization:vinod-techops-org:project:Default Project:workspace:azure-dev:run_phase:apply",
  "audiences": ["api://AzureADTokenExchange"],
  "description": "HCP Terraform azure-dev workspace, apply phase"
}
EOF

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters /tmp/fedcred-apply.json

rm /tmp/fedcred-plan.json /tmp/fedcred-apply.json
```

> **Subject claim is case-sensitive** and spaces in `Default Project` must be preserved literally.

### 1.5 Verify

```sh
az ad app federated-credential list --id "$APP_ID" --output table
az role assignment list --assignee "$APP_ID" --output table
```

### 1.6 Configure HCP Terraform workspace variables

In HCP UI: **vinod-techops-org → Default Project → azure-dev → Variables → Add variable**

| Key | Category | Value | Sensitive |
|---|---|---|---|
| `TFC_AZURE_PROVIDER_AUTH` | Environment | `true` | no |
| `TFC_AZURE_RUN_CLIENT_ID` | Environment | *(value of `$APP_ID`)* | no |
| `ARM_SUBSCRIPTION_ID` | Environment | *(value of `$SUB_ID`)* | no |
| `ARM_TENANT_ID` | Environment | *(value of `$TENANT_ID`)* | no |

Save. The workspace is now ready to authenticate to Azure with zero stored secrets.

### 1.7 Record the IDs

Save these values somewhere you can retrieve later (password manager or `.env` that stays out of git). You'll reference them in Phase 5 when configuring GitHub Actions:

```
APP_ID       = <appId from 1.2>
SUB_ID       = <subscription id>
TENANT_ID    = <tenant id>
```

---

## Phase 2 — Provision Azure infra via HCP Terraform

*(Written in Phase 2 of the build plan — placeholder.)*

## Phase 3 — Bootstrap ArgoCD

*(Placeholder.)*

## Phase 4 — Deploy Spring Boot services

*(Placeholder.)*

## Phase 5 — Wire GitHub Actions CI

*(Placeholder.)*

## Teardown

*(Placeholder — destroys all Azure resources and federated credentials.)*
