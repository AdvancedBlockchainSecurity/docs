# Feature Test: Quality Gates (CI/CD Integration)

**Feature**: Quality Gates for CI/CD Pipeline Integration (Phase 5.5c)
**Version**: 0.10.2 (API), 0.29.0 (Dashboard)
**Date**: January 12, 2026
**Status**: Implemented
**Updated**: Dashboard integration into ProjectDetail page with TierGate

---

## Overview

Quality Gates enable CI/CD pipeline integration for automated security scanning with configurable blocking rules. Projects can define thresholds for vulnerability counts and severity levels that determine whether a build passes or fails. This feature supports build status badges, evaluation history, and CI context tracking.

## Test Cases

### TC-40.1: Quality Gate Panel Display

**Objective**: Verify the Quality Gate panel displays in project detail page

**Prerequisites**:
- User authenticated on Developer tier or higher
- At least one project exists

**Steps**:
1. Navigate to Dashboard
2. Click on a project
3. Scroll to Quality Gates section (below Project Access Panel)
4. Verify Quality Gate panel is visible

**Expected Results**:
- [ ] Quality Gate panel visible below Access Control section
- [ ] TierGate wrapper shows upgrade prompt for Free tier users
- [ ] Panel shows current configuration (if exists)
- [ ] Configuration form visible for editing
- [ ] Badge preview displayed

---

### TC-40.2: Tier Restriction - Developer Tier

**Objective**: Verify Developer tier users cannot access Quality Gates

**Prerequisites**:
- User authenticated on Developer tier (free)

**Steps**:
1. Navigate to project settings
2. Attempt to access Quality Gate configuration

**Expected Results**:
- [ ] Quality Gate tab/option not visible or disabled
- [ ] Upgrade prompt displayed
- [ ] Message: "Quality Gates are available on Team tier and above"
- [ ] API returns 403 for direct endpoint access

---

### TC-40.3: Configure Quality Gate via API

**Objective**: Verify quality gate can be configured via API

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s -X PUT "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Security Gate",
    "block_on_critical": true,
    "block_on_high": true,
    "max_critical": 0,
    "max_high": 5,
    "max_medium": 20,
    "max_low": -1
  }' | jq
```

**Expected Results**:
- [ ] Response contains quality gate configuration
- [ ] `id` is UUID
- [ ] `project_id` matches request
- [ ] All threshold values saved correctly
- [ ] `created_at` and `updated_at` timestamps present
- [ ] `is_active` defaults to true

---

### TC-40.4: Get Quality Gate Configuration

**Objective**: Verify quality gate configuration can be retrieved

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains complete quality gate configuration
- [ ] All configured thresholds returned
- [ ] `is_active` status included
- [ ] Response is 404 if no quality gate configured

---

### TC-40.5: Evaluate Scan Against Quality Gate

**Objective**: Verify scan evaluation works correctly

**Prerequisites**:
- Quality gate configured for project
- Completed scan exists for project

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
SCAN_ID="your-scan-uuid"
curl -s -X POST "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID/evaluate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "scan_id": "'$SCAN_ID'",
    "triggered_by": "manual"
  }' | jq
```

**Expected Results**:
- [ ] Response contains `status` (passing/failing)
- [ ] Response contains `passed` boolean
- [ ] `critical_count`, `high_count`, `medium_count`, `low_count` present
- [ ] `violations` array lists any threshold violations
- [ ] Each violation contains `rule`, `threshold`, `actual`, `severity`, `message`

---

### TC-40.6: Evaluation with CI Context

**Objective**: Verify CI context is properly stored with evaluation

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
SCAN_ID="your-scan-uuid"
curl -s -X POST "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID/evaluate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "scan_id": "'$SCAN_ID'",
    "triggered_by": "ci",
    "ci_context": {
      "branch": "feature/my-feature",
      "commit": "abc123def456",
      "pr": 42,
      "workflow": "Security Scan",
      "run_id": "12345678"
    }
  }' | jq
```

**Expected Results**:
- [ ] Response includes `ci_context` data
- [ ] `triggered_by` shows "ci"
- [ ] All CI context fields preserved
- [ ] `evaluated_at` timestamp present

---

### TC-40.7: Block on Critical Rule

**Objective**: Verify block_on_critical rule works

**Test Data**: Scan with 1+ critical vulnerability

**Steps**:
1. Configure quality gate with `block_on_critical: true`
2. Evaluate scan with critical vulnerabilities

**Expected Results**:
- [ ] `passed` is `false`
- [ ] `status` is `failing`
- [ ] Violations include `block_on_critical` rule
- [ ] Violation message: "Critical vulnerabilities block enabled and 1 critical found"

---

### TC-40.8: Block on High Rule

**Objective**: Verify block_on_high rule works

**Test Data**: Scan with 1+ high vulnerability (no critical)

**Steps**:
1. Configure quality gate with `block_on_high: true`
2. Evaluate scan with high vulnerabilities

**Expected Results**:
- [ ] `passed` is `false`
- [ ] `status` is `failing`
- [ ] Violations include `block_on_high` rule
- [ ] Violation message: "High vulnerabilities block enabled and X high found"

---

### TC-40.9: Max Threshold Rules

**Objective**: Verify max_* threshold rules

**Test Data**: Scan with 3 high vulnerabilities

**Steps**:
1. Configure quality gate with `max_high: 2`
2. Evaluate scan

**Expected Results**:
- [ ] `passed` is `false`
- [ ] Violations include `max_high` rule
- [ ] Violation shows `threshold: 2`, `actual: 3`
- [ ] Message: "High vulnerabilities (3) exceed threshold (2)"

---

### TC-40.10: Passing Quality Gate

**Objective**: Verify quality gate passes when thresholds met

**Test Data**: Scan with 0 critical, 2 high (threshold: 5)

**Steps**:
1. Configure quality gate with `max_critical: 0`, `max_high: 5`
2. Evaluate scan with 0 critical, 2 high

**Expected Results**:
- [ ] `passed` is `true`
- [ ] `status` is `passing`
- [ ] `violations` is empty array
- [ ] Severity counts still returned

---

### TC-40.11: Get Build Status (CI/CD)

**Objective**: Verify build status endpoint for CI/CD integration

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID/build-status" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `project_id`
- [ ] `status` is one of: passing, failing, pending
- [ ] `quality_gate_name` shown
- [ ] Severity counts included
- [ ] `violations` array (if failing)
- [ ] `badge_url` for README embedding

---

### TC-40.12: SVG Badge Endpoint

**Objective**: Verify SVG badge endpoint works

**Steps**:
```bash
PROJECT_ID="your-project-uuid"
curl -s "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID/badge.svg"
```

**Expected Results**:
- [ ] Content-Type is `image/svg+xml`
- [ ] Returns valid SVG
- [ ] Badge shows "passing" (green) or "failing" (red) or "pending" (yellow)
- [ ] No authentication required (public endpoint)
- [ ] Cache-Control header set for 5 minutes

---

### TC-40.13: Evaluation History

**Objective**: Verify evaluation history retrieval

**Steps**:
```bash
TOKEN=$(bash /Users/pwner/Git/ABS/docs/scripts/get_token_fixed.sh)
PROJECT_ID="your-project-uuid"
curl -s "http://localhost:8000/api/v1/quality-gates/projects/$PROJECT_ID/history?limit=10" \
  -H "Authorization: Bearer $TOKEN" | jq
```

**Expected Results**:
- [ ] Response contains `items` array
- [ ] Each item has evaluation details
- [ ] Ordered by `evaluated_at` descending
- [ ] `total` count included
- [ ] Pagination supported (limit, offset)

---

### TC-40.14: Default Quality Gate (No Configuration)

**Objective**: Verify behavior when no quality gate configured

**Steps**:
1. Select project without quality gate
2. Request build status

**Expected Results**:
- [ ] HTTP 404 or status "pending"
- [ ] Clear message: "No quality gate configured for this project"
- [ ] Prompt to configure quality gate

---

### TC-40.15: Unlimited Threshold (-1)

**Objective**: Verify -1 means unlimited (no check)

**Steps**:
1. Configure quality gate with `max_medium: -1`
2. Evaluate scan with 100+ medium vulnerabilities

**Expected Results**:
- [ ] No violation for medium count
- [ ] Other thresholds still enforced
- [ ] Gate can pass despite high medium count

---

### TC-40.16: Authorization - Cross-Project Access

**Objective**: Verify users cannot access other users' quality gates

**Steps**:
1. Get project ID from User A
2. Attempt to access with User B's token

**Expected Results**:
- [ ] HTTP 403 Forbidden
- [ ] Error message: "Not authorized to access this project"
- [ ] No configuration data leaked

---

### TC-40.17: Dashboard Configuration UI

**Objective**: Verify dashboard quality gate configuration UI

**Prerequisites**:
- User on Team tier or higher
- Project exists

**Steps**:
1. Navigate to project settings
2. Open Quality Gate tab
3. Toggle block options
4. Adjust threshold sliders
5. Save configuration

**Expected Results**:
- [ ] Toggle switches for block_on_critical, block_on_high
- [ ] Sliders or inputs for max_* thresholds
- [ ] "-1" or "Unlimited" option for no limit
- [ ] Save button enabled when changes made
- [ ] Success toast on save
- [ ] Configuration persisted on page refresh

---

### TC-40.18: Dashboard Build Status Display

**Objective**: Verify build status displayed in project overview

**Steps**:
1. Navigate to project with quality gate configured
2. View project overview

**Expected Results**:
- [ ] Build status badge visible
- [ ] Color indicates pass (green) / fail (red) / pending (yellow)
- [ ] Click navigates to quality gate details
- [ ] Last evaluation timestamp shown

---

### TC-40.19: Dashboard Violations Display

**Objective**: Verify violations displayed in quality gate panel

**Prerequisites**:
- Failing quality gate evaluation

**Steps**:
1. Navigate to project with failing quality gate
2. View quality gate panel

**Expected Results**:
- [ ] Violations list visible
- [ ] Each violation shows rule, threshold, actual, severity
- [ ] Severity icons/colors applied
- [ ] Clear indication of what needs fixing

---

### TC-40.20: GitHub Actions Integration

**Objective**: Verify GitHub Actions workflow example works

**Steps**:
1. Copy example from docs/ci-cd/github-actions-example.yaml
2. Set up repository secrets:
   - `APOGEE_API_KEY`
   - `APOGEE_PROJECT_ID`
3. Trigger workflow

**Expected Results**:
- [ ] Workflow uploads contracts for scanning
- [ ] Workflow waits for scan completion
- [ ] Quality gate evaluation executes
- [ ] Workflow fails if gate fails
- [ ] PR comment posted (if PR event)

---

## API Reference

### GET /api/v1/quality-gates/projects/{project_id}
Returns quality gate configuration for a project.

### PUT /api/v1/quality-gates/projects/{project_id}
Creates or updates quality gate configuration.

### POST /api/v1/quality-gates/projects/{project_id}/evaluate
Evaluates a scan against the quality gate.

### GET /api/v1/quality-gates/projects/{project_id}/build-status
Returns current build status for CI/CD integration.

### GET /api/v1/quality-gates/projects/{project_id}/badge.svg
Returns SVG badge (public, no auth required).

### GET /api/v1/quality-gates/projects/{project_id}/history
Returns evaluation history with pagination.

---

## Quality Gate Configuration

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | required | Gate name |
| `block_on_critical` | boolean | true | Fail on ANY critical |
| `block_on_high` | boolean | false | Fail on ANY high |
| `max_critical` | integer | 0 | Max critical allowed (-1 = unlimited) |
| `max_high` | integer | -1 | Max high allowed (-1 = unlimited) |
| `max_medium` | integer | -1 | Max medium allowed (-1 = unlimited) |
| `max_low` | integer | -1 | Max low allowed (-1 = unlimited) |
| `is_active` | boolean | true | Gate activation status |

---

## Violation Response Structure

```json
{
  "rule": "max_critical",
  "threshold": 0,
  "actual": 2,
  "severity": "critical",
  "message": "Critical vulnerabilities (2) exceed threshold (0)"
}
```

---

## Build Status Values

| Status | Color | Description |
|--------|-------|-------------|
| `passing` | Green | No violations, gate passed |
| `failing` | Red | One or more violations |
| `pending` | Yellow | No evaluation yet or no gate configured |

---

## Tier Requirements (4-Tier Model)

| Tier | Price | Quality Gates Access |
|------|-------|---------------------|
| Developer | $0 | Not available |
| Team | $299/mo | Full access |
| Growth | $699/mo | Full access |
| Enterprise | $1,999+/mo | Full access |

---

## CI/CD Integration Examples

### GitHub Actions
See: `/docs/ci-cd/github-actions-example.yaml`

### GitLab CI
See: `/docs/ci-cd/README.md`

### CircleCI
See: `/docs/ci-cd/README.md`

---

## Badge Integration

Add to README:
```markdown
[![Security](https://api.0xapogee.com/api/v1/quality-gates/projects/YOUR_PROJECT_ID/badge.svg)](https://app.0xapogee.com/projects/YOUR_PROJECT_ID)
```

Note: Badge is cached for 5 minutes. Append `?t=timestamp` to force refresh.
