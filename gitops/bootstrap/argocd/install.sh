#!/usr/bin/env bash
# One-shot ArgoCD bootstrap for AKS cluster aks-asbdemo-dev-sin.
#
# Prereqs (run once on the workstation):
#   az aks get-credentials -g rg-asbdemo-dev-sin -n aks-asbdemo-dev-sin --overwrite-existing
#   helm repo add argo https://argoproj.github.io/argo-helm && helm repo update
#
# Re-running is safe (helm upgrade --install + kubectl apply).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_NAMESPACE="${ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${ARGOCD_CHART_VERSION:-7.6.12}"

echo "==> Creating namespace ${ARGOCD_NAMESPACE}"
kubectl get ns "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 \
  || kubectl create namespace "${ARGOCD_NAMESPACE}"

echo "==> Installing / upgrading ArgoCD (chart ${ARGOCD_CHART_VERSION})"
helm upgrade --install argocd argo/argo-cd \
  --namespace "${ARGOCD_NAMESPACE}" \
  --version "${ARGOCD_CHART_VERSION}" \
  --values "${SCRIPT_DIR}/values.yaml" \
  --wait --timeout 10m

echo "==> Applying root Application (workloads/envs/dev)"
kubectl apply -f "${SCRIPT_DIR}/root-app.yaml"

echo
echo "==> ArgoCD is up. Initial admin password:"
kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

cat <<EOF

Access the UI:
  kubectl -n ${ARGOCD_NAMESPACE} port-forward svc/argocd-server 8080:443
  open https://localhost:8080  (username: admin)

Watch the root Application sync:
  kubectl -n ${ARGOCD_NAMESPACE} get application workloads-dev -w
EOF
