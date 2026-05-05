# Terraform Policy as Code (OPA/Conftest)

This directory contains organization policies for Infrastructure as Code validation using **OPA (Open Policy Agent)** and **Conftest**.

## Overview

Policies are enforced at two levels:

1. **Local** — Before committing code (fast feedback loop)
2. **CI/CD** — In GitHub Actions before apply (final gate)

## Policy Categories

### 1. **Naming Conventions** (`naming.rego`)
- Ensures all resources follow the pattern: `<type>-asbdemo-<env>-<region>`
- Examples: `rg-asbdemo-dev-sin`, `aks-asbdemo-prod-sin`

### 2. **Required Tags** (`tags.rego`)
- Enforces mandatory tags on all resources:
  - `app` — Application name
  - `environment` — Environment (dev/prod/hub)
  - `managed_by` — Set to "terraform"
  - `repo` — Repository name
- Warns if tag values are suspicious or mismatched

### 3. **Cost Control** (`cost.rego`)
- Blocks expensive SKUs in dev environment (Premium ACR, Standard ServiceBus)
- Warns about large VM sizes and excessive log retention in dev
- Prevents runaway costs

### 4. **Termination Protection** (`termination.rego`)
- **BLOCKS** deletion of prod resource groups (critical safety check)
- **BLOCKS** deletion of prod AKS clusters (data loss)
- **BLOCKS** deletion of prod Key Vaults (secrets loss)
- **BLOCKS** deletion of prod ServiceBus (queue loss)
- Warns on deletion of other prod resources

### 5. **RBAC** (`rbac.rego`)
- Warns if prod resources lack RBAC configuration
- Denies excessive "Owner" role assignments
- Warns about deprecated roles (Contributor, Administrator)
- Checks for orphaned role assignments

## Installation

### Prerequisites

```bash
# Conftest (OPA policy tester)
wget https://github.com/open-policy-agent/conftest/releases/download/v0.46.0/conftest_0.46.0_Linux_x86_64.tar.gz
tar xzf conftest_0.46.0_Linux_x86_64.tar.gz
sudo mv conftest /usr/local/bin/

# On macOS
brew install conftest

# Verify
conftest --version  # should be v0.46.0 or later
```

### Directory Structure

```
infra/
├── .conftest/
│   ├── conftest.toml           # Conftest config (namespace = terraform)
│   ├── policy/
│   │   ├── naming.rego         # Resource naming standards
│   │   ├── tags.rego           # Required tag enforcement
│   │   ├── cost.rego           # Cost control (prevent expensive SKUs)
│   │   ├── termination.rego    # Termination protection for prod
│   │   └── rbac.rego           # RBAC validation
│   └── data/
│       └── defaults.json       # (Optional) Org policy data
└── README.md                   # This file
```

## Local Testing

### Step 1: Generate Terraform Plan (JSON)

```bash
# From your environment directory
cd infra/terragrunt/envs/dev

# Generate plan in JSON format (required for Conftest)
terragrunt plan -json > /tmp/dev-plan.json

# Or directly with terraform
terraform plan -json > /tmp/dev-plan.json
```

### Step 2: Run Conftest

```bash
# From repo root
cd infra

# Test against all policies
conftest test \
  -p .conftest/policy \
  /tmp/dev-plan.json \
  --namespace terraform \
  --output table

# Or with JSON output for parsing
conftest test \
  -p .conftest/policy \
  /tmp/dev-plan.json \
  --namespace terraform \
  --output json | jq .
```

### Step 3: Interpret Results

**Output format:**
```
PASS: (zero violations)
WARN: (warnings — non-blocking but review recommended)
FAIL: (denials — blocks apply)
```

**Example:**
```
$ conftest test -p .conftest/policy /tmp/dev-plan.json --namespace terraform --output table

FAIL - infra/.conftest/policy/termination.rego - ❌ TERMINATION BLOCKED: Cannot delete prod Resource Group 'rg-asbdemo-prod-sin'. ...

FAIL - infra/.conftest/policy/tags.rego - ❌ TAGS: Resource 'azurerm_kubernetes_cluster.main' (type: azurerm_kubernetes_cluster) missing required tags: [...]

WARN - infra/.conftest/policy/cost.rego - ⚠️ COST: Log Analytics workspace in dev has 90 days retention...

PASS - (all other policies passed)

1 failure, 1 warning, 5 passes in "dev-plan.json"
```

## Common Workflows

### Before committing code:

```bash
# 1. Make Terraform changes
# 2. Generate plan
terragrunt plan -json > /tmp/plan.json

# 3. Test policies
conftest test -p .conftest/policy /tmp/plan.json --namespace terraform --output table

# 4. If FAIL violations → Fix and repeat
# If WARN only → Review and proceed
```

### Testing a specific policy:

```bash
# Test only naming policy
conftest test \
  -p .conftest/policy/naming.rego \
  /tmp/dev-plan.json \
  --namespace terraform
```

### Running all tests locally (all envs):

```bash
#!/bin/bash
for env in dev prod hub; do
  echo "Testing $env..."
  cd infra/terragrunt/envs/$env
  terragrunt plan -json > /tmp/${env}-plan.json
  cd ../../../..
  conftest test -p .conftest/policy /tmp/${env}-plan.json --namespace terraform --output table
  echo "---"
done
```

## GitHub Actions Integration

When you push a PR with infrastructure changes:

1. **Trigger**: Changes to `infra/terraform/**`, `infra/terragrunt/**`, or `.conftest/**`
2. **Execution**: `.github/workflows/terraform-policy.yml` runs automatically
3. **Steps**:
   - Generates `terragrunt plan -json` for each env (dev, prod, hub)
   - Runs Conftest against each plan
   - Comments on PR with violations or clearance
4. **Result**:
   - ✅ **PASS** — All policies satisfied, ready to merge
   - ⚠️ **WARNINGS** — Review suggestions, merge allowed
   - ❌ **FAIL** — Policy denials block merge until fixed

### Viewing CI results:

- **PR comment**: GitHub automatically posts policy results
- **Artifacts**: Policy reports saved for 7 days: `Actions > Artifacts > policy-report-{env}`

## Policy Violations & Fixes

### Example 1: Resource missing required tag

**Violation:**
```
❌ TAGS: Resource 'azurerm_kubernetes_cluster.main' missing required tags: [environment]
```

**Fix:**
Edit Terraform code to add missing tag in `locals.tf` or resource definition:
```hcl
tags = {
  app         = var.app_name
  environment = var.environment    # ← Add this
  managed_by  = "terraform"
  repo        = "azureservicebus"
}
```

### Example 2: Trying to delete prod resource

**Violation:**
```
❌ TERMINATION BLOCKED: Cannot delete prod Resource Group 'rg-asbdemo-prod-sin'. 
   Manually enable 'destroy' override if absolutely necessary.
```

**Fix (if delete is truly intentional):**

In Terraform, override protect_destroy temporarily:
```hcl
terraform {
  lifecycle {
    ignore_lifecycle_rules = true  # NOT RECOMMENDED — use only in emergencies
  }
}
```

Better: Use `terraform destroy -target` with manual approval process.

### Example 3: Premium ACR in dev

**Violation:**
```
❌ COST: Resource 'azurerm_container_registry.main' cannot use SKU 'Premium' in dev. 
   Use 'Basic' for dev. Cost impact: Premium=$200+/mo vs Basic=$5/mo
```

**Fix:**
Change ACR SKU in `shared/main.tf`:
```hcl
module "acr" {
  source = "../../modules/acr"
  ...
  sku = var.environment == "prod" ? "Premium" : "Basic"  # ← Add logic
}
```

Or add a variable override in dev's `terragrunt.hcl`.

## Adding New Policies

To add a new policy:

1. Create `infra/.conftest/policy/<policy-name>.rego`
2. Write Rego rules (see examples in existing policies)
3. Test locally: `conftest test -p .conftest/policy/<policy-name>.rego /tmp/plan.json`
4. CI automatically includes new policies on next PR

## Disabling Policies Temporarily

If a policy blocks a legitimate use case, you can:

1. **Disable in code**: Add a comment `# conftest-skip=<policy-name>` (note: requires custom Conftest wrapper)
2. **Disable in CI**: Modify `.conftest/conftest.toml` to exclude policy
3. **Override variables**: Pass Terragrunt `inputs` that satisfy the policy

**Best practice:** Never disable; fix the root cause instead.

## Resources

- [OPA/Rego Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Conftest Documentation](https://www.conftest.dev/)
- [Terraform Plan JSON Schema](https://www.terraform.io/internals/json-format)
- [Rego Playground](https://play.openpolicyagent.org/)

## Support

For questions or to suggest new policies:

1. Check existing issues in the repo
2. Review policy `.rego` files for inline documentation
3. Test locally before asking for help: `conftest test -p .conftest/policy <plan.json> -v` (verbose mode)

## Changelog

### v1.0 (Initial release)
- Naming convention policy
- Required tags enforcement
- Cost control (prevent expensive SKUs in dev)
- Termination protection for prod
- RBAC validation
