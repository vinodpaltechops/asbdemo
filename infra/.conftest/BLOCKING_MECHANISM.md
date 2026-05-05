# Policy Blocking Mechanism - How PR Merge is Blocked

This document explains exactly how the GitHub Actions workflow blocks PRs when policy denials are found.

## High-Level Flow

```
Developer pushes code
        ↓
GitHub triggers PR workflow
        ↓
┌─────────────────────────────────┐
│   PHASE 1: POLICY (parallel)    │
│  ┌─────────┬─────────┬─────┐   │
│  │   dev   │  prod   │ hub │   │
│  ├─────────┼─────────┼─────┤   │
│  │ plan    │ plan    │plan │   │
│  │conftest │conftest │conf │   │
│  └─────────┴─────────┴─────┘   │
│  Output: JSON policy reports    │
└─────────────────────────────────┘
        ↓
┌─────────────────────────────────┐
│  PHASE 2: POLICY-SUMMARY        │
│  Parse reports → Comment on PR  │
└─────────────────────────────────┘
        ↓
┌─────────────────────────────────┐
│  PHASE 3: POLICY-GATE           │
│  ┌─────────────────────────────┐│
│  │ Check if denials found      ││
│  │ ┌──────────────────────────┐││
│  │ │ For each env (dev/prod):  │││
│  │ │  - Read policy report     │││
│  │ │  - Count denials          │││
│  │ │  - If count > 0 → FAIL    │││
│  │ └──────────────────────────┘││
│  │                              ││
│  │ Result: exit 1 if denials    ││
│  │ Result: exit 0 if pass       ││
│  └─────────────────────────────┘│
│                                  │
│ Set GitHub Check:               │
│  ✅ PASSED (exit 0)             │
│  ❌ FAILED (exit 1)             │
└─────────────────────────────────┘
        ↓
   GitHub PR Status
   ┌─────────────────┐
   │ ✅ if PASSED    │
   │ ❌ if FAILED    │
   └─────────────────┘
        ↓
┌──────────────────────────────────┐
│ Can merge if all checks pass?    │
│                                  │
│ Policy-Gate = PASSED  → ✅ CAN   │
│ Policy-Gate = FAILED  → ❌ BLOCK │
└──────────────────────────────────┘
```

## Exact Code Location: How It Blocks

### File: `.github/workflows/terraform-policy.yml`

#### Job: `policy-gate` (Lines 195-263)

```yaml
policy-gate:
  name: Policy Gate
  runs-on: ubuntu-latest
  needs: policy          # ← Waits for all policy jobs to complete
  if: always()          # ← Runs even if policy jobs fail
  
  steps:
    - name: Check for policy denials
      id: check
      run: |
        # ↓ This step counts denials in JSON reports
        DENIALS_FOUND=0
        for env in dev prod hub; do
          DENIAL_COUNT=$(jq '[.[] | select(.failures != null) | .failures[]] | length' "$REPORT_FILE")
          if [ "$DENIAL_COUNT" -gt 0 ]; then
            DENIALS_FOUND=1
          fi
        done
        
        # ↓ Sets output variable
        echo "check_result=$DENIALS_FOUND" >> $GITHUB_OUTPUT
        
        # ↓ THIS IS THE BLOCKING LINE - Exit code 1 = Fail
        if [ $DENIALS_FOUND -eq 1 ]; then
          exit 1  # ← BLOCKS PR (exit code non-zero)
        else
          exit 0  # ← Allows PR (exit code zero)
        fi
```

#### Exit Codes (Critical)

```
exit 0 = Success (GitHub shows ✅ green checkmark)
exit 1 = Failure (GitHub shows ❌ red X, BLOCKS merge)
```

#### GitHub Check Creation (Lines 248-263)

```javascript
github.rest.checks.create({
  name: 'Policy Validation Gate',
  conclusion: checkResult === '0' ? 'success' : 'failure',
  // ↑ This sets the PR status that GitHub branch protection rules check
});
```

---

## Three Types of Results

### Result 1: All Policies PASSED ✅

```
Conftest output:
  0 denials, 0 warnings → PASS

Workflow:
  policy-gate runs: DENIALS_FOUND=0
  exit 0 → GitHub Check = ✅ PASSED
  
PR Status:
  ✅ All checks passed
  Merge button: ENABLED
```

### Result 2: Policies have WARNINGS ⚠️ (but no denials)

```
Conftest output:
  0 denials, 3 warnings → WARN (non-blocking)

Workflow:
  policy-gate runs: DENIALS_FOUND=0
  exit 0 → GitHub Check = ✅ PASSED
  
PR Status:
  ✅ All checks passed (warnings don't block)
  Merge button: ENABLED
  PR comment: Lists warnings for review
```

### Result 3: Policies have DENIALS ❌

```
Conftest output:
  2 denials, 1 warning → FAIL (blocks)

Workflow:
  policy-gate runs: DENIALS_FOUND=1
  exit 1 → GitHub Check = ❌ FAILED
  
PR Status:
  ❌ Policy Validation Gate check FAILED
  Merge button: DISABLED (if branch protection enabled)
  PR comment: Lists denials (must be fixed)
```

---

## How GitHub Branch Protection Works

For the merge block to take effect, you need to configure GitHub branch protection:

### Step 1: Enable Branch Protection on `main`

Go to: **Repository → Settings → Branches → Add rule**

```
Branch name pattern: main
Require status checks to pass before merging: ✅ ENABLED
```

### Step 2: Select Required Check

Under "Require status checks to pass", select:
- ✅ `Policy Validation Gate` (our check)
- ✅ Any other checks you want (tests, lint, etc.)

### Step 3: Result

```
Merge Behavior:
┌──────────────────────────────────┐
│ If Policy-Gate = ✅ PASSED       │
│   → Merge button: ENABLED        │
│                                  │
│ If Policy-Gate = ❌ FAILED       │
│   → Merge button: DISABLED       │
│   → Show: "Merging blocked"      │
└──────────────────────────────────┘
```

---

## Code Path: Step-by-Step

### 1. Conftest Runs, Generates JSON Report

**File:** `.github/workflows/terraform-policy.yml` lines 86-95

```yaml
- name: Run OPA Policies
  working-directory: infra
  run: |
    conftest test \
      -p .conftest/policy \
      /tmp/${{ matrix.env }}-plan.json \
      --namespace terraform \
      --output json > /tmp/${{ matrix.env }}-policy-report.json
    # Output: /tmp/dev-policy-report.json (JSON with failures/warnings)
```

### 2. JSON Report Structure

Example `dev-policy-report.json`:
```json
[
  {
    "filename": "dev-plan.json",
    "namespace": "terraform",
    "successes": 5,
    "failures": [
      "❌ TERMINATION BLOCKED: Cannot delete prod Resource Group..."
    ],
    "warnings": [
      "⚠️ COST: Log Analytics workspace in dev has 90 days retention..."
    ]
  }
]
```

### 3. Policy-Gate Job Counts Failures

**File:** `.github/workflows/terraform-policy.yml` lines 209-221

```bash
# Parse JSON report
DENIAL_COUNT=$(jq '[.[] | select(.failures != null) | .failures[]] | length' "$REPORT_FILE")
#                   ↑ Extracts all failure messages
#                   ↑ Counts them
# If any denials: DENIAL_COUNT > 0 → Set DENIALS_FOUND=1
```

### 4. Exit Code Determines Pass/Fail

**File:** `.github/workflows/terraform-policy.yml` lines 222-231

```bash
if [ $DENIALS_FOUND -eq 1 ]; then
  echo "❌ Policy Denials Found"
  exit 1  # ← Non-zero exit = GitHub sees FAILURE
else
  echo "✅ No policy denials found"
  exit 0  # ← Zero exit = GitHub sees SUCCESS
fi
```

### 5. GitHub Check Status

**File:** `.github/workflows/terraform-policy.yml` lines 237-263

```javascript
github.rest.checks.create({
  conclusion: checkResult === '0' ? 'success' : 'failure'
  //          ↑ Uses exit code from step 4
  //          If exit code was 0: conclusion = 'success' (✅)
  //          If exit code was 1: conclusion = 'failure' (❌)
});
```

### 6. GitHub PR Status

GitHub checks the conclusion from step 5:
```
conclusion = 'success' → ✅ Check passed → Merge allowed
conclusion = 'failure' → ❌ Check failed → Merge blocked
```

---

## Where the Blocking Actually Happens

**The block happens at the GitHub UI level, not in our code:**

```
Our Workflow Code (GitHub Actions):
  exit 1 → Sets GitHub Check conclusion = 'failure'
              ↓
GitHub PR UI:
  Checks 'Policy Validation Gate': ❌ FAILED
              ↓
Branch Protection Rule (Admin Settings):
  "Require status checks to pass"
              ↓
Result:
  Merge button: DISABLED
  Message: "Merging blocked by Policy Validation Gate"
```

---

## Testing the Block Locally

To test that the policy gate works correctly:

### Test 1: Verify Policy Reports Are Generated

```bash
cd infra/terragrunt/envs/dev
terragrunt plan -json > /tmp/dev-plan.json

# This creates the JSON that policy-gate will parse
ls -lh /tmp/dev-plan.json
```

### Test 2: Verify Conftest Output Format

```bash
conftest test -p .conftest/policy /tmp/dev-plan.json \
  --namespace terraform \
  --output json | jq '.[] | .failures | length'
# Should return number of denials
```

### Test 3: Verify Exit Code Logic (Simulate policy-gate)

```bash
# Simulating the policy-gate job locally
REPORT_FILE="/tmp/dev-policy-report.json"
conftest test -p .conftest/policy /tmp/dev-plan.json \
  --namespace terraform \
  --output json > "$REPORT_FILE"

# Count denials
DENIAL_COUNT=$(jq '[.[] | select(.failures != null) | .failures[]] | length' "$REPORT_FILE" 2>/dev/null || echo "0")

if [ "$DENIAL_COUNT" -gt 0 ]; then
  echo "❌ WOULD BLOCK: $DENIAL_COUNT denials found"
  echo "Exit code: 1"
else
  echo "✅ WOULD ALLOW: No denials"
  echo "Exit code: 0"
fi
```

---

## Summary: The Blocking Chain

```
┌─────────────────────────────────────────────────┐
│ 1. Conftest finds policy violation              │
│    → Creates JSON report with failures field    │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 2. policy-gate job downloads JSON reports       │
│    → Parses with `jq` to count denials          │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 3. Check logic: if denials > 0                  │
│    → Set DENIALS_FOUND=1                        │
│    → exit 1                                     │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 4. GitHub Actions sees exit code = 1            │
│    → Sets GitHub Check: conclusion = 'failure'  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 5. GitHub PR UI shows:                          │
│    ❌ Policy Validation Gate: FAILED            │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─────────────────────────────────────────────────┐
│ 6. Branch protection rule sees failed check     │
│    → Disables merge button                      │
│    → Shows: "Merging blocked by..."             │
└─────────────────────────────────────────────────┘
```

---

## What Happens When PR Has Denials

### Developer pushes code with policy violation:
```
Naming violation: Resource "aks-badname" doesn't match pattern
```

### Workflow runs:
```
✅ Terraform Plan: Generated
✅ Policy Check (dev): FOUND 1 DENIAL
✅ Policy Summary: Posted comment on PR
✅ Policy Gate: Found denials, exit 1
```

### GitHub PR Status:
```
All checks:
  ❌ Policy Validation Gate: FAILED

Merge button:
  DISABLED
  "Merging blocked by failed status check"

PR Comment:
  "❌ NAMING: Resource 'aks-badname' has invalid name..."
```

### Developer must:
1. Fix the resource name
2. Push fix
3. Workflow re-runs automatically
4. If no denials: ✅ Check passes → Merge allowed

---

## Key Files

| File | Purpose | Blocking Logic |
|------|---------|---|
| `.conftest/policy/*.rego` | OPA rules | Denies/warns violations |
| `.github/workflows/terraform-policy.yml` (lines 195-263) | Policy gate | Counts denials, exits 1 if found |
| GitHub Branch Protection Settings | Admin config | Requires check to pass |

That's the complete blocking mechanism!
