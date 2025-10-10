# How to Disable/Control GitHub Actions

**Version:** 1.0.0
**Last Updated:** October 9, 2025
**Purpose:** Save costs by controlling when GitHub Actions run

---

## Quick Answer

To disable GitHub Actions on feature branches and only run on PRs:

**Edit `.github/workflows/test.yml` - Change lines 3-6 from:**
```yaml
on:
  push:
    branches: [main, develop, 'feature/**']  # ← Runs on EVERY push
  pull_request:
    branches: [main, develop]
```

**To:**
```yaml
on:
  pull_request:
    branches: [main, develop]  # ← Only run on PRs
  push:
    branches: [main, develop]   # ← Keep for deployments
  workflow_dispatch:             # ← Manual trigger option
```

**Result:** 96% cost reduction ($1,000/year savings)

---

## Why Control GitHub Actions?

### Current Cost
- **Every push** to feature/** triggers workflow
- 50 pushes/week/developer × 5 developers = 250 runs/week
- 250 runs × $0.08 = **$20/week = $1,040/year**

### With Local Testing
- Developers test with `act` locally (free)
- GitHub Actions only runs on PRs (10/week)
- 10 runs × $0.08 = **$0.80/week = $42/year**
- **Savings: $1,000/year (96% reduction)**

---

## Methods to Disable/Control

### Method 1: Modify Workflow Triggers (✅ Recommended)

**Edit:** `.github/workflows/test.yml`

**Option A: PR-Only (Recommended)**
```yaml
on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]  # Keep for deployments
  workflow_dispatch:  # Manual trigger
```

**Option B: Manual-Only (Maximum Savings)**
```yaml
on:
  workflow_dispatch:  # Only manual triggers
  pull_request:
    types: [ready_for_review]  # Only when PR ready
```

### Method 2: Use [skip ci] in Commits

```bash
# Skip GitHub Actions for this commit
git commit -m "WIP: Testing [skip ci]"

# Accepted formats:
# [skip ci], [ci skip], [no ci], [skip actions], [actions skip]
```

### Method 3: Disable via GitHub Settings

1. Repository → **Settings** → **Actions** → **General**
2. Under "Actions permissions", select **"Disable actions"**
3. Click **Save**

**Note:** Requires admin access, not version controlled

### Method 4: Rename Workflow Directory (Temporary)

```bash
# Disable all workflows
mv .github/workflows .github/workflows.disabled
git add .github/ && git commit -m "Disable workflows" && git push

# Re-enable later
mv .github/workflows.disabled .github/workflows
git add .github/ && git commit -m "Re-enable workflows" && git push
```

---

## Recommended Implementation

### Step 1: Test Workflow Locally

```bash
# Verify workflow works with act
act -l  # List workflows
act -j quality  # Test quality checks
```

### Step 2: Update Workflow File

```bash
# Edit workflow file
vim .github/workflows/test.yml
```

**Find:**
```yaml
on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main, develop]
```

**Replace with:**
```yaml
on:
  # Only run on pull requests
  pull_request:
    branches: [main, develop]

  # Keep deployments for main/develop
  push:
    branches: [main, develop]

  # Allow manual trigger from GitHub UI
  workflow_dispatch:
```

### Step 3: Test Changes Locally

```bash
# Test with act
act -j test  #Should still work

# Create branch and test
git checkout -b optimize-workflows
git add .github/workflows/test.yml
git commit -m "Optimize GitHub Actions to run only on PRs"
git push origin optimize-workflows
```

### Step 4: Create PR and Verify

1. Create PR on GitHub
2. Verify GitHub Actions runs on the PR
3. Check that it didn't run on the push to your feature branch

### Step 5: Merge and Document

```bash
# After PR approved and merged
# Update team documentation
# Notify team to use `act` for local testing
```

---

## Development Workflow

### Before (Expensive, Slow)
```
1. Write code
2. git commit && git push
3. Wait ~10 minutes for GitHub Actions
4. Check results
5. Repeat if failed
```

**Cost:** $0.08 per iteration × 10 iterations = $0.80

### After (Free, Fast)
```
1. Write code
2. act -j quality  (~1 min, local)
3. act -j test     (~5 min, local)
4. If pass: git commit && git push
5. Create PR when ready (GitHub Actions validates once)
```

**Cost:** $0.08 × 1 PR = $0.08 (90% savings)

---

## Testing Different Trigger Types

```bash
# Test pull request trigger
act pull_request

# Test push trigger
act push

# Test manual trigger
act workflow_dispatch

# Dry run (show what would execute)
act -n
```

---

## Common Scenarios

### Scenario 1: Disable on All Feature Branches

**Current:**
```yaml
push:
  branches: [main, develop, 'feature/**']
```

**Modified:**
```yaml
push:
  branches: [main, develop]  # Removed 'feature/**'
```

### Scenario 2: Only Run on PR Approval

```yaml
on:
  pull_request:
    types: [ready_for_review, synchronize]
```

### Scenario 3: Skip Docs-Only Changes

```yaml
on:
  pull_request:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'
      - '!docs/**'  # Ignore docs changes
      - '!*.md'      # Ignore markdown
```

### Scenario 4: Manual Trigger Only

```yaml
on:
  workflow_dispatch:  # Only manual triggers
  push:
    branches: [main]  # Auto-deploy production only
```

---

## Rollback Plan

If you need to re-enable automatic runs on all branches:

```bash
# Revert workflow changes
git revert <commit-hash>
git push

# OR manually edit .github/workflows/test.yml back to:
on:
  push:
    branches: [main, develop, 'feature/**']
  pull_request:
    branches: [main, develop]
```

---

## Cost Comparison Table

| Scenario | Runs/Week | Cost/Week | Cost/Year |
|----------|-----------|-----------|-----------|
| **Current** (every push) | 250 | $20 | $1,040 |
| **PR-Only** | 10 | $0.80 | $42 |
| **Manual-Only** | 2-5 | $0.16-$0.40 | $8-$21 |
| **Savings** | -96% | -96% | **-$998** |

---

## FAQ

**Q: Will this break CI/CD?**
A: No. PRs still get validated. Main/develop still auto-deploy.

**Q: What if I need to run workflows on a feature branch?**
A: Use `workflow_dispatch` (manual trigger) or `act` locally.

**Q: How do I trigger manually?**
A: Go to Actions tab → Select workflow → Run workflow button.

**Q: Can I test this without breaking production?**
A: Yes. Test with `act` locally, then deploy to a test repository first.

**Q: What about required status checks?**
A: Update branch protection rules to require PR checks, not push checks.

---

## Summary

✅ **Recommended:** Update workflow to run only on PRs
✅ **Savings:** ~$1,000/year for 5-developer team
✅ **Speed:** 50% faster with local `act` testing
✅ **CI/CD:** Still validates PRs before merge
✅ **Flexibility:** Manual trigger still available

**Next Steps:**
1. Review `docs/LOCAL-TESTING-SETUP.md`
2. Test with `act -j quality`
3. Update workflow triggers
4. Create PR to validate changes

---

**Created:** October 9, 2025
**Related Docs:**
- `docs/LOCAL-GITHUB-ACTIONS.md` - Full act guide
- `docs/LOCAL-TESTING-SETUP.md` - Quick start
- `docs/TESTING.md` - Testing guide
