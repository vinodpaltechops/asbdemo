# Infrastructure (Terraform + Terragrunt)

Terraform modules under `modules/` are orchestrated per environment by
Terragrunt leaves living **inside each env's Terraform root**. The
single `root.hcl` is shared by every leaf.

## Layout

```
infra/
├── root.hcl                    # Terragrunt root — inherited by every leaf
├── _envcommon/                 # (empty) shared module wirings, added in Phase A.2
├── envs/
│   └── azure-dev/              # existing Terraform root for the dev env
│       ├── main.tf
│       ├── variables.tf
│       ├── versions.tf         # cloud{} block → HCP workspace "azure-dev"
│       ├── ...
│       └── terragrunt.hcl      # leaf — wraps this root in-place
└── modules/                    # reusable Terraform modules
    ├── aks/
    ├── network/
    ├── servicebus/
    ├── observability/
    └── ...
```

The leaf lives inside `envs/azure-dev/` (same dir as `main.tf`) so
Terragrunt runs Terraform from there directly. No `terraform.source`,
no copy to `.terragrunt-cache/`, no path resolution surprises — module
references like `../../modules/network` work because we ARE in
`envs/azure-dev/` when terraform runs.

## Why Terragrunt at all

Adding prod (and later stage) without copy-pasting the dev TF root.
Terragrunt gives us:

- **DRY config** — backend / providers / common inputs defined once at the root; each leaf is ~10 lines
- **Per-leaf state** — each leaf maps to its own HCP workspace; smaller blast radius and faster plans
- **Module dependencies** — `dependency` blocks declare order (hub → spoke → AKS); `run-all` applies in correct order
- **No copy-paste** — adding prod = a new directory with 4-5 small `terragrunt.hcl` files referencing the same `infra/modules/`

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **A.1** (this PR) | In-place leaf inside `envs/azure-dev/`. No state migration. Validates Terragrunt wiring. | here |
| **A.2** | Split the monolithic `envs/azure-dev/main.tf` into per-component leaves (network, acr, servicebus, aks, observability). Each gets its own HCP workspace. | next |
| **B** | Add `envs/azure-hub/` for shared resources (ACR, private DNS, Log Analytics). Spokes peer to hub. | |
| **C** | Add `envs/azure-prod/` — clones dev structure, different sizing/naming. | |
| **D** | GitOps for prod cluster (ArgoCD multi-cluster). | |
| **E** | NSGs + NAT Gateway in hub for egress controls. | |

## Usage

Install:

```bash
brew install terragrunt terraform
terragrunt --version
terraform --version

# first-time HCP auth (once per machine)
terraform login app.terraform.io
```

Plan dev:

```bash
cd infra/envs/azure-dev
terragrunt plan
```

Apply dev:

```bash
cd infra/envs/azure-dev
terragrunt apply
```

Plan all envs (becomes useful in Phase A.2+):

```bash
cd infra/envs
terragrunt run-all plan
```

## Phase A.1 expected behavior

`terragrunt plan` from `infra/envs/azure-dev/`:

1. Terragrunt reads `terragrunt.hcl` here, walks up to find `infra/root.hcl`
2. Includes root config (currently no-op — just documentation)
3. Runs `terraform init` from this directory
4. Runs `terraform plan` — uses the HCP cloud{} block in `versions.tf`, hits HCP workspace `azure-dev`
5. Reports **No changes** because we're driving the same code that's already managing the cluster

If the plan shows resource changes, something's drifted between local state and HCP — investigate before applying.

## What does NOT change in this phase

- HCP workspace `azure-dev` is still authoritative for state
- HCP plan-on-merge still triggers on commits to `infra/envs/azure-dev/`
- `infra/modules/` is untouched
- CI workflows are untouched

The Terragrunt layout is **additive** — the `terragrunt.hcl` is the only new file inside the env dir; everything else (main.tf, versions.tf, providers.tf) is unchanged.
