# azureservicebus

End-to-end demo: **Spring Boot ↔ Azure Service Bus** on **AKS**, provisioned by **Terraform**, delivered via **GitOps (ArgoCD + Argo Rollouts)**, observed via **Prometheus + Grafana + ELK**.

## Architecture

```
 GitHub ──push──▶ GitHub Actions (CI, runner: ARC on AWS EKS)
                 ├─ mvn verify
                 ├─ docker build + Trivy scan
                 ├─ push image → ACR (OIDC federation, no secrets)
                 └─ commit image tag → gitops/

 ArgoCD (on AKS) ──watches gitops/──▶ reconciles manifests
                                      ├─ platform-addons (App-of-Apps)
                                      └─ workloads (App-of-Apps)

 AKS:
   ├─ NGINX Gateway Fabric  (Gateway API, traffic ingress)
   ├─ cert-manager          (Let's Encrypt via HTTP-01, nip.io hostnames)
   ├─ Argo Rollouts         (+ Gateway API trafficrouter plugin)
   ├─ kube-prometheus-stack (Prometheus, Alertmanager, Grafana)
   ├─ ECK + Filebeat        (Elasticsearch + Kibana + log shipper)
   └─ Workloads:
        ├─ orders-service   (producer)  → Rollout: canary
        └─ payments-service (consumer)  → Rollout: blue-green
              └─── AMQP ──▶ Azure Service Bus Queue
```

## Tech + decisions

| Area | Choice |
|---|---|
| Region | `southindia` |
| Cluster | AKS (1 system + 1 user nodepool, B-series) |
| Registry | Azure Container Registry (Basic) |
| Messaging | Azure Service Bus **Basic** (queues only, point-to-point) |
| Secrets | Azure Key Vault + CSI driver |
| Identity | AKS Workload Identity → Service Bus (no connection strings) |
| App | Java 21, Spring Boot 3.3, Maven |
| Observability | Prometheus + Grafana (kube-prometheus-stack); ELK via ECK + Filebeat |
| Traffic | **Gateway API** via **NGINX Gateway Fabric** |
| TLS | cert-manager + Let's Encrypt + `nip.io` |
| GitOps | ArgoCD (App-of-Apps), bootstrapped by Terraform `helm_release` |
| Progressive delivery | Argo Rollouts (canary for `orders`, blue-green for `payments`) |
| CI | GitHub Actions, runner: existing ARC on AWS EKS, OIDC federation to Azure |
| IaC | Terraform (mono-repo `infra/`) |

## Repo layout

```
.
├── README.md
├── .gitignore
├── .editorconfig
│
├── app/                               # Spring Boot source
│   ├── pom.xml                        # parent pom
│   ├── orders-service/                # producer (canary rollout demo)
│   └── payments-service/              # consumer (blue-green rollout demo)
│
├── infra/                             # Terraform
│   ├── backend/                       # bootstrap: storage for tfstate
│   ├── modules/
│   │   ├── naming/
│   │   ├── network/                   # vnet, subnets, nsg
│   │   ├── keyvault/
│   │   ├── acr/
│   │   ├── monitoring/                # log analytics, diag settings
│   │   ├── aks/                       # cluster + nodepools + workload identity
│   │   └── servicebus/                # namespace + queue + auth rules
│   └── envs/
│       ├── platform/                  # RG, network, KV, ACR, LAW
│       └── dev/                       # AKS, Service Bus, app identities, ArgoCD (helm_release)
│
├── gitops/                            # ArgoCD source of truth
│   ├── bootstrap/                     # root App-of-Apps
│   ├── platform-addons/
│   │   ├── nginx-gateway-fabric/
│   │   ├── cert-manager/
│   │   ├── argo-rollouts/
│   │   ├── kube-prometheus-stack/
│   │   ├── eck-operator/
│   │   ├── elasticsearch-kibana/
│   │   └── filebeat/
│   └── workloads/
│       ├── orders-service/            # Rollout (canary) + HTTPRoute + AnalysisTemplate + ServiceMonitor
│       └── payments-service/          # Rollout (blue-green) + HTTPRoute + ServiceMonitor
│
├── .github/workflows/
│   ├── terraform.yml                  # fmt/validate/plan on PR, apply on main
│   ├── app-ci.yml                     # build, test, scan, push, gitops bump
│   └── security.yml                   # tfsec, checkov, Trivy
│
└── docs/
    ├── architecture.md
    └── runbook.md
```

## Execution phases

| Phase | Deliverable |
|---|---|
| 0 | Repo skeleton + README + .gitignore (this commit) |
| 1 | Terraform backend bootstrap |
| 2 | Landing zone (RGs, VNet, KV, ACR, LAW) |
| 3 | AKS + Service Bus + workload identity |
| 4 | Spring Boot services (orders, payments) |
| 5 | Dockerfiles + GitHub Actions CI (OIDC to Azure) |
| 6 | ArgoCD install (Terraform `helm_release`) + App-of-Apps |
| 7 | Platform addons via ArgoCD |
| 8 | Workload Rollouts + Gateway API HTTPRoutes |
| 9 | Grafana dashboards + PrometheusRules (SLOs) |
| 10 | Docs + teardown script |

## Getting started

Detailed steps are in [docs/runbook.md](docs/runbook.md) (written in Phase 10). TL;DR:

```sh
# 1. Azure auth (federated from GH Actions in CI; az login locally)
az login && az account set --subscription <SUB_ID>

# 2. Bootstrap tfstate backend
cd infra/backend && terraform init && terraform apply

# 3. Landing zone
cd ../envs/platform && terraform init && terraform apply

# 4. Workload infra (AKS, Service Bus, ArgoCD)
cd ../dev && terraform init && terraform apply

# 5. ArgoCD takes over — it reconciles everything in gitops/
```
