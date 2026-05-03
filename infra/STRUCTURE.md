# Infrastructure Structure: Terraform + Terragrunt

## Architecture Overview

This structure separates **Terraform code** (pure infrastructure) from **Terragrunt** (orchestration layer).

```
infra/
├── terraform/                     ← Pure Terraform (can be used standalone)
│   ├── envs/
│   │   ├── azure-dev/            ← Dev environment (full implementation)
│   │   ├── azure-prod/           ← Prod environment (placeholder)
│   │   └── azure-hub/            ← Hub/firewall (placeholder)
│   └── modules/                  ← Shared Terraform modules
│       ├── network/
│       ├── aks/
│       ├── keyvault/
│       ├── monitoring/
│       ├── servicebus/
│       ├── acr/
│       └── workload-identity/
│
└── terragrunt/                    ← Orchestration layer (thin wrappers)
    ├── env.hcl                    ← Shared environment variables
    ├── root.hcl                   ← Common provider config
    └── envs/
        ├── dev/terragrunt.hcl
        ├── prod/terragrunt.hcl
        └── hub/terragrunt.hcl
```

## Key Design Decisions

### 1. **Separation of Concerns**
- **`terraform/`**: Contains all Terraform code, completely independent of Terragrunt
- **`terragrunt/`**: Thin wrappers that orchestrate Terraform environments
- You can use Terraform directly if needed: `cd terraform/envs/azure-dev && terraform plan`

### 2. **3 HCP Terraform Workspaces** (not per-component)
- `dev` — Development environment
- `prod` — Production environment (future)
- `hub` — Hub/shared infrastructure (firewall, gateway resources)

This is simpler, cleaner, and appropriate for your current scale. You can add component-level workspace splitting later if needed.

### 3. **Each Environment is Self-Contained**
Each leaf in `terragrunt/envs/<env>/` has its own:
- Backend configuration (HCP Terraform workspace name)
- Terraform source reference
- Environment-specific variables

## Usage

### Using Terragrunt (recommended for orchestration)
```bash
cd infra/terragrunt/envs/dev
terragrunt plan
terragrunt apply
```

### Using Terraform Directly
```bash
cd infra/terraform/envs/azure-dev
terraform plan
terraform apply
```

## Configuration Files

### `infra/terragrunt/env.hcl`
Shared variables across all environments:
- `org`: HCP Terraform organization name
- `location`, `location_short`: Azure region
- `app_name`, `environment`: Application details
- `tags`: Common Azure resource tags

### `infra/terragrunt/root.hcl`
Common configuration inherited by all environment leaves:
- Provider configuration (azurerm, azuread features)
- Common inputs passed to all environments

### `infra/terragrunt/envs/<env>/terragrunt.hcl`
Environment-specific configuration:
- Points to Terraform source: `../../terraform/envs/azure-<env>`
- Generates backend config with workspace name
- Passes environment-specific variables

## Next Steps

1. **Create 3 HCP Terraform workspaces**:
   - Organization: `vinod-techops-org`
   - Workspace names: `dev`, `prod`, `hub`
   - Execution mode: Local (for now)

2. **Authenticate Terraform locally**:
   - Generate HCP Terraform API token
   - Run `terraform login` to configure credentials

3. **Test the setup**:
   - `cd infra/terragrunt/envs/dev && terragrunt validate`
   - `terragrunt plan` (should match existing infrastructure)

4. **Migrate state** (if switching from existing workspace):
   - Perform state migration only if you have an existing `azure-dev` workspace
   - Otherwise, import existing resources or keep old workspace until ready

## Migration Path (if you have existing state)

If you already have a monolithic `azure-dev` workspace:

```bash
# Pull current state
cd infra/terraform/envs/azure-dev
terraform state pull > /tmp/current.tfstate

# Push to new workspace
cd ../../../terragrunt/envs/dev
terragrunt init
terragrunt state push /tmp/current.tfstate

# Verify
terragrunt plan  # Should show "No changes"
```

## Scaling Considerations

### If you later need per-component workspaces:
Instead of modifying the existing structure, create sub-leaves:

```
terragrunt/envs/dev/
├── network/terragrunt.hcl         ← References terraform/modules/network
├── aks/terragrunt.hcl             ← References terraform/modules/aks
└── keyvault/terragrunt.hcl        ← References terraform/modules/keyvault
```

This keeps the structure clean and doesn't disrupt the existing full-environment approach.

## Files to Update

### CI/CD Configuration
Update `.github/workflows/terraform.yml`:
- Change working directory to `infra/terragrunt/envs/dev`
- Use `terragrunt plan` and `terragrunt apply`

### Documentation
- Update any references to old `infra/envs/` paths
- Document the 3-workspace approach for team members
