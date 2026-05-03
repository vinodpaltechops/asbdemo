# azure-dev Terraform stack

Single stack provisioned by the HCP Terraform workspace `vinod-techops-org/azure-dev`.

## What it creates

- Resource group `rg-asbdemo-dev-sin`
- VNet + 3 subnets (aks-system, aks-user, pe) + NSG
- Log Analytics Workspace (AKS diagnostics target)
- Key Vault (RBAC-authorized; secrets for cert-manager, etc.)
- ACR (Basic SKU) — AKS kubelet has AcrPull role
- AKS cluster (system + user nodepools, workload identity + OIDC issuer enabled, Container Insights → LAW)
- Service Bus namespace (Basic) + `orders` queue
- 2 user-assigned managed identities with federated credentials:
  - `mi-orders-…` → Sender role on `orders` queue; federated to `asbdemo/orders-sa` SA
  - `mi-payments-…` → Receiver role on `orders` queue; federated to `asbdemo/payments-sa` SA

## Running

**First time only:** in HCP UI → workspace `azure-dev` → Settings → General → **Terraform Working Directory** = `infra/envs/azure-dev`. Save.

### Remote (via HCP — recommended)

```sh
cd infra/envs/azure-dev
terraform login                        # one-time, stores HCP token locally
terraform init
terraform plan                         # runs in HCP, streams output to your terminal
terraform apply
```

### Local (not recommended)
HCP workspace is `remote` execution. `terraform plan` will always run on HCP runners regardless of where you invoke it from.

## Cost note (free-tier)

Dominant cost: AKS nodes. Default sizing (1× B2s system + 1-3× B2ms user) runs roughly ₹3-5k/month if left on 24/7. See `docs/runbook.md` → "Pause for cost savings" for the `az aks stop` escape hatch.

## Outputs to use downstream

- `acr_login_server` → GitHub Actions pushes images here
- `workload_identities` → used to annotate Kubernetes ServiceAccounts in `gitops/workloads/`
- `servicebus_fqdn` → set as `SERVICEBUS_FQDN` env var on each Spring Boot pod
- `aks_oidc_issuer_url` → sanity check, already wired into federated credentials
