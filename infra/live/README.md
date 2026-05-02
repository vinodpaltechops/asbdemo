# Terragrunt live configuration

This directory orchestrates the Terraform under `infra/envs/` and
`infra/modules/` per environment, with shared config promoted to a
single root `terragrunt.hcl`.

## Layout

```
infra/live/
├── terragrunt.hcl            # root config — inherited by every leaf
├── _envcommon/               # (empty) shared module wirings, added in Phase A.2
└── dev/
    ├── env.hcl               # dev-specific values (region, naming)
    └── terragrunt.hcl        # leaf — currently wraps infra/envs/azure-dev/
```

## Why Terragrunt

We want a clean way to add prod (and later stage) without copy-pasting the dev TF root. Terragrunt gives us:

- **DRY config**: backend, providers, common inputs defined once at the root; each leaf is ~10 lines
- **Per-leaf state**: each leaf maps to its own HCP workspace; smaller blast radius and faster plans
- **Module dependencies**: `dependency` blocks declare order (hub → spoke → AKS); `run-all` applies in correct order
- **No copy-paste**: adding prod = a new directory with 4-5 small `terragrunt.hcl` files referencing the same `infra/modules/`

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **A.1** (this PR) | Add Terragrunt scaffolding wrapping the existing dev root. No state migration. | here |
| **A.2** | Decompose dev into per-component leaves (network, aks, servicebus, observability). Each gets its own HCP workspace. | next |
| **B** | Add `hub/` leaf for shared resources (ACR, private DNS zones, log analytics). Spokes peer to hub. | |
| **C** | Add `prod/` leaf — clones dev structure, different sizing/naming. | |
| **D** | GitOps for prod cluster (ArgoCD multi-cluster). | |
| **E** | NSGs + NAT Gateway in hub for egress controls. | |

## Usage

Install Terragrunt:

```bash
brew install terragrunt
terragrunt --version
```

Plan dev:

```bash
cd infra/live/dev
terragrunt plan
```

Apply dev:

```bash
cd infra/live/dev
terragrunt apply
```

Plan all envs (becomes useful in Phase A.2+):

```bash
cd infra/live
terragrunt run-all plan
```

## Phase A.1 expected behavior

`terragrunt plan` from `infra/live/dev/` does the following under the hood:

1. Read `infra/live/terragrunt.hcl` (root) and `infra/live/dev/env.hcl`
2. Copy `infra/envs/azure-dev/` into a temp `.terragrunt-cache/` directory
3. Pass env.hcl inputs as `TF_VAR_*` environment variables
4. Run `terraform init` (uses HCP cloud{} block from the wrapped `versions.tf`)
5. Run `terraform plan` — should report **No changes** because we're wrapping the same code that's already managing the cluster

If you see resource changes in the plan, something in the wrapper drifted from the original root — investigate before applying.

## What does NOT change in this phase

- HCP workspace `azure-dev` is still authoritative for state
- `infra/envs/azure-dev/` keeps working as before; HCP plan-on-merge still triggers on commits there
- `infra/modules/` is untouched
- CI workflows are untouched

The Terragrunt layout is **additive** — we run it locally to validate equivalence, then start using it as the canonical entry point in Phase A.2.
