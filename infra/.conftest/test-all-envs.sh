#!/bin/bash
#
# test-all-envs.sh - Test all environments (dev, prod, hub) against OPA policies
# Usage: ./infra/.conftest/test-all-envs.sh

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFTEST_DIR="$REPO_ROOT/infra/.conftest"
TG_ROOT="$REPO_ROOT/infra/terragrunt/envs"

ENVIRONMENTS=("dev" "prod" "hub")
FAILED=0

echo "🔐 Testing all environments against OPA policies..."
echo "=================================================="
echo ""

for env in "${ENVIRONMENTS[@]}"; do
  echo "📋 Testing $env environment..."
  echo "   Generating terraform plan..."

  cd "$TG_ROOT/$env"

  # Generate plan
  if ! terragrunt plan -json > "/tmp/${env}-plan.json" 2>&1; then
    echo "❌ Failed to generate plan for $env"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Run conftest
  cd "$REPO_ROOT"
  echo "   Running policy checks..."

  if conftest test \
    -p "$CONFTEST_DIR/policy" \
    "/tmp/${env}-plan.json" \
    --namespace terraform \
    --output table 2>&1 | tee "/tmp/${env}-policy-report.txt"; then
    echo "✅ $env: PASSED"
  else
    echo "❌ $env: FAILED (see above for violations)"
    FAILED=$((FAILED + 1))
  fi

  echo ""
done

echo "=================================================="
if [ $FAILED -eq 0 ]; then
  echo "✅ All environments passed policy checks!"
  exit 0
else
  echo "❌ $FAILED environment(s) failed policy checks"
  echo ""
  echo "Reports saved to /tmp/*-policy-report.txt"
  exit 1
fi
