# Complete Policy Workflow: From Conftest to Merge Block

This document shows the complete end-to-end workflow of how policies are enforced.

## The Three-Tier Policy Enforcement System

```
TIER 1: LOCAL (Developer)
├─ Developer runs: conftest test -p .conftest/policy <plan.json>
├─ Gets instant feedback (pass/warn/fail)
└─ Fixes before committing

        ↓

TIER 2: CI/CD (GitHub Actions)
├─ Triggered on PR with changes
├─ Parallel jobs for dev, prod, hub
├─ Generates policy reports
├─ Comments on PR with results
└─ No blocking yet (informational)

        ↓

TIER 3: MERGE GATE (GitHub Branch Protection)
├─ policy-gate job checks all reports
├─ Counts denials across all environments
├─ Exits with code 1 if denials found
├─ GitHub sees failure → Disables merge button
└─ Developer must fix violations to merge
```

---

## Tier 1: Local Testing (Before Commit)

### Command:
```bash
conftest test -p .conftest/policy <plan.json> --namespace terraform --output table
```

### Flow:
```
1. Developer makes changes
2. Runs: terragrunt plan -json > /tmp/plan.json
3. Runs: conftest test -p .conftest/policy /tmp/plan.json
4. Gets immediate results:
   ├─ ✅ PASS: no issues, safe to commit
   ├─ ⚠️ WARN: review recommendations, can commit
   └─ ❌ FAIL: policy denials, must fix before commit
```

### Example Output:
```
$ conftest test -p .conftest/policy /tmp/dev-plan.json --namespace terraform --output table

FAIL - infra/.conftest/policy/naming.rego - ❌ NAMING: Resource 'aks-badname' has invalid name

WARN - infra/.conftest/policy/cost.rego - ⚠️ COST: Log retention is 90 days in dev

PASS - 8 policies passed

1 failure, 1 warning, 8 passes in "dev-plan.json"
```

### Developer Action:
- ❌ Has denials → Fix and re-test locally
- ⚠️ Has warnings → Review and decide
- ✅ All pass → Safe to commit

---

## Tier 2: GitHub Actions (PR Validation)

### Trigger:
```
Push to PR with changes to:
  - infra/terraform/**
  - infra/terragrunt/**
  - .conftest/**
```

### GitHub Workflow: `.github/workflows/terraform-policy.yml`

```
GITHUB PR CREATED
        ↓
[Workflow Triggered]
        ↓
┌────────────────────────────────────────────────────────────┐
│ JOB: policy (Parallel for dev, prod, hub)                  │
├─────────┬─────────┬────────────────────────────────────────┤
│  dev    │  prod   │  hub                                   │
├─────────┼─────────┼────────────────────────────────────────┤
│ 1. terraform plan -json → /tmp/dev-plan.json               │
│ 2. conftest test -p policy /tmp/dev-plan.json --output json│
│ 3. Results → /tmp/dev-policy-report.json                   │
│ 4. Upload artifact: policy-report-dev                      │
└─────────┴─────────┴────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────────────────────┐
│ JOB: policy-summary                                        │
├────────────────────────────────────────────────────────────┤
│ 1. Download all policy reports (dev, prod, hub)            │
│ 2. Parse reports with jq                                   │
│ 3. Create comprehensive PR comment with:                   │
│    - Dev/prod/hub individual results                       │
│    - Total denials + warnings count                        │
│    - Links to full reports                                 │
│ 4. Post comment on PR                                      │
└────────────────────────────────────────────────────────────┘
        ↓
┌────────────────────────────────────────────────────────────┐
│ JOB: policy-gate (BLOCKING GATE)                           │
├────────────────────────────────────────────────────────────┤
│ 1. Download all policy reports                             │
│ 2. FOR each environment:                                   │
│    - Count denials in JSON report                          │
│    - If count > 0: set DENIALS_FOUND=1                     │
│ 3. IF DENIALS_FOUND:                                       │
│    - echo "❌ Policy Denials Found"                        │
│    - exit 1  ← CRITICAL: Non-zero exit = Failure           │
│ 4. ELSE:                                                   │
│    - echo "✅ No policy denials found"                     │
│    - exit 0  ← Zero exit = Success                         │
│ 5. GitHub sees exit code:                                  │
│    - exit 1 → Check conclusion = 'failure' (❌ FAILED)    │
│    - exit 0 → Check conclusion = 'success' (✅ PASSED)    │
└────────────────────────────────────────────────────────────┘
```

### What GitHub Shows on PR:

#### Scenario A: All Policies Pass ✅
```
Checks:
  ✅ Policy Validation Gate: PASSED

Results:
  0 denials, 0 warnings
  
Action:
  Merge button: ENABLED
  Developer can merge
```

#### Scenario B: Policies Have Warnings ⚠️
```
Checks:
  ✅ Policy Validation Gate: PASSED (warnings don't block)

Results:
  0 denials, 3 warnings
  
PR Comment:
  "Review suggestions for cost optimization..."
  
Action:
  Merge button: ENABLED
  Developer can merge if they review warnings
```

#### Scenario C: Policies Have Denials ❌
```
Checks:
  ❌ Policy Validation Gate: FAILED

Results:
  2 denials, 1 warning
  
PR Comment:
  "Naming violation: Resource must match pattern..."
  "Termination blocked: Cannot delete prod resources..."
  
Action:
  Merge button: DISABLED
  Message: "Merging blocked by failed status check"
  Developer MUST fix and push new commit
```

---

## Tier 3: GitHub Branch Protection

### Configuration (Done in GitHub UI)

**Path:** Repository → Settings → Branches → Add rule

```
Branch name pattern: main

✅ Require status checks to pass before merging
   Selected checks:
   ☑ Policy Validation Gate  ← Our check
   ☑ Other checks (tests, lint, etc.)
```

### How It Blocks

```
When Developer clicks "Merge":
├─ GitHub checks all required status checks
├─ Finds: Policy Validation Gate = ❌ FAILED
├─ Result: MERGE BLOCKED
└─ Message: "Merging blocked by failed status check:
              Policy Validation Gate"
```

---

## Complete End-to-End Example

### Scenario: Developer Makes Naming Mistake

#### Step 1: Local Development
```bash
# Developer edits main.tf
resource "azurerm_kubernetes_cluster" "main" {
  name = "aks-badname"  # ❌ Wrong pattern!
  ...
}

# Developer tests locally
$ terragrunt plan -json > /tmp/plan.json
$ conftest test -p .conftest/policy /tmp/plan.json --namespace terraform

❌ NAMING: Resource 'aks-badname' has invalid name. 
   Expected format: <type>-asbdemo-<env>-<region>

# Developer realizes mistake: should be "aks-asbdemo-dev-sin"
# Options:
#   a) Fix locally and re-test
#   b) Push anyway to see CI fail
```

#### Step 2: Developer Pushes PR (with mistake)

```bash
git add infra/terraform/envs/shared/main.tf
git commit -m "Add AKS cluster"
git push origin fix/aks-cluster
```

#### Step 3: GitHub Actions Runs

```
Workflow: terraform-policy.yml triggered
├─ policy job (dev):
│  ├─ terragrunt plan -json
│  ├─ conftest test → finds naming denial
│  └─ Creates report: /tmp/dev-policy-report.json
│     {
│       "failures": [
│         "❌ NAMING: Resource 'aks-badname' has invalid name..."
│       ]
│     }
├─ policy-summary job:
│  └─ Posts PR comment with findings
└─ policy-gate job:
   ├─ Reads /tmp/dev-policy-report.json
   ├─ jq counts failures: 1 denial found
   ├─ Sets: DENIALS_FOUND=1
   ├─ Runs: exit 1 ← FAILURE
   └─ GitHub sees: exit 1 → Check = ❌ FAILED
```

#### Step 4: GitHub PR Shows Status

```
PR Page:
├─ Checks:
│  └─ ❌ Policy Validation Gate: FAILED
│
├─ Comment from github-actions:
│  "❌ NAMING: Resource 'aks-badname' has invalid name.
│     Expected format: <type>-asbdemo-<env>-<region>"
│
└─ Merge button:
   DISABLED (red)
   "Merging blocked by failed status check"
```

#### Step 5: Developer Fixes & Re-Commits

```bash
# Fix the name
resource "azurerm_kubernetes_cluster" "main" {
  name = "aks-asbdemo-dev-sin"  # ✅ Correct!
}

# Test locally
$ terragrunt plan -json > /tmp/plan.json
$ conftest test -p .conftest/policy /tmp/plan.json
✅ PASS: All policies passed

# Push fix
git add infra/terraform/envs/shared/main.tf
git commit -m "Fix AKS cluster naming"
git push origin fix/aks-cluster
```

#### Step 6: Workflow Re-Runs (Auto)

```
Workflow triggered again:
├─ policy job (dev):
│  ├─ terragrunt plan -json → finds NO violations
│  └─ Creates report: /tmp/dev-policy-report.json
│     {
│       "failures": [],  ← Empty!
│       "warnings": []   ← Empty!
│     }
└─ policy-gate job:
   ├─ Reads /tmp/dev-policy-report.json
   ├─ jq counts failures: 0 denials
   ├─ Sets: DENIALS_FOUND=0
   ├─ Runs: exit 0 ← SUCCESS
   └─ GitHub sees: exit 0 → Check = ✅ PASSED
```

#### Step 7: GitHub PR Now Allows Merge

```
PR Page:
├─ Checks:
│  └─ ✅ Policy Validation Gate: PASSED
│
├─ Previous comment updated:
│  "✅ All policies passed"
│
└─ Merge button:
   ENABLED (green)
   "All checks have passed"
```

#### Step 8: Developer Merges

```bash
Developer clicks: "Merge Pull Request"
GitHub:
  ✅ All required checks passed
  ✅ No conflicts
  → Merge succeeds
  → Commits to main
```

---

## Key Files & Their Roles

### Policy Files (What We Check)
```
infra/.conftest/policy/
├─ naming.rego          ← Resource naming validation
├─ tags.rego            ← Required tags enforcement
├─ cost.rego            ← Cost control (prevent expensive SKUs)
├─ termination.rego     ← Protect prod from deletion
└─ rbac.rego            ← RBAC configuration validation
```

### Workflow File (How We Check)
```
.github/workflows/terraform-policy.yml
├─ Lines 1-30: Comments explaining 3-phase process
├─ Lines 50-120: policy job (parallel Conftest for each env)
├─ Lines 125-179: policy-summary job (PR comment)
└─ Lines 195-263: policy-gate job (BLOCKING EXIT CODE)
                  ^^^^^^^^^^ THIS IS THE BLOCKER
```

### Infrastructure Code (What We Protect)
```
infra/terraform/envs/shared/main.tf
├─ lifecycle { prevent_destroy = ... }  ← Termination protection
└─ azurerm_role_assignment               ← RBAC enforcement
```

---

## Exit Codes: The Critical Part

### This is where the blocking happens:

```bash
# In policy-gate job:

if [ $DENIALS_FOUND -eq 1 ]; then
  echo "❌ Policy Denials Found"
  exit 1  ← THIS LINE BLOCKS THE PR
else
  echo "✅ No policy denials found"
  exit 0  ← This allows merge
fi
```

### How GitHub Interprets Exit Codes:

```
exit 0 (Success)
  ↓
GitHub: Check concluded with status = 'success'
  ↓
GitHub PR UI: ✅ Check passed
  ↓
Branch Protection: Check passed, allow merge
  ↓
Merge Button: ENABLED

────────────────────────────────────────

exit 1 (Failure)
  ↓
GitHub: Check concluded with status = 'failure'
  ↓
GitHub PR UI: ❌ Check failed
  ↓
Branch Protection: Check failed, block merge
  ↓
Merge Button: DISABLED
```

---

## Testing the Complete Flow

### Test 1: Verify Local Conftest Works
```bash
cd infra/terragrunt/envs/dev
terragrunt plan -json > /tmp/plan.json
conftest test -p ../../.conftest/policy /tmp/plan.json --namespace terraform
# Should show PASS or WARN (not FAIL)
```

### Test 2: Simulate Policy-Gate Job Locally
```bash
REPORT_FILE="/tmp/dev-policy-report.json"

# Generate report (simulating policy job)
conftest test -p infra/.conftest/policy /tmp/plan.json \
  --namespace terraform --output json > "$REPORT_FILE"

# Run policy-gate logic (simulating gate job)
DENIALS_FOUND=0
DENIAL_COUNT=$(jq '[.[] | select(.failures != null) | .failures[]] | length' "$REPORT_FILE" 2>/dev/null || echo "0")
if [ "$DENIAL_COUNT" -gt 0 ]; then
  DENIALS_FOUND=1
fi

if [ $DENIALS_FOUND -eq 1 ]; then
  echo "Would BLOCK (exit 1)"
  exit 1
else
  echo "Would ALLOW (exit 0)"
  exit 0
fi

echo "Exit code: $?"  # Should be 0 if no denials
```

### Test 3: Create a Deliberate Violation to See It Block

```bash
# Temporarily violate a policy in main.tf
# Example: change SKU from Basic to Premium in dev

# Then run: conftest test ...
# Should show FAIL for cost.rego

# Run the gate logic above
# Should output: "Would BLOCK (exit 1)"
# And: "Exit code: 1"
```

---

## Summary

The blocking mechanism works in three tiers:

1. **Local (Developer)**: Fast feedback before commit
2. **CI/CD (GitHub Actions)**: Automated validation + PR comment
3. **Merge Gate (Branch Protection)**: Exit code 1 → GitHub blocks merge

The critical line is: **`exit 1`** in the policy-gate job
- When this runs, GitHub sees failure
- Branch protection rule blocks the merge
- Merge button becomes disabled
- Developer must fix and push again

That's how policy denials actually block PRs!
