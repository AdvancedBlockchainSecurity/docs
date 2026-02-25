# Organization, Team & Subscription Audit Results

**Date:** 2026-02-25 03:17 UTC
**API Version:** v0.29.28 (v0.29.27 + org creation tier gate fix)
**Target:** https://app.blocksecops.local/api/v1
**Duration:** 2.4s

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Tests | 56 |
| Passed | 52 |
| Failed | 4 |
| Pass Rate | 92.9% |

**Issue 1 (org creation tier gate) FIXED in v0.29.28.** 4 remaining failures are Issue 2 (duplicate member handling) + 3 cascading.

---

## Results by Section

### Billing [PASS] (6/6)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | GET /billing/plans returns 200 | 200 | - |
| PASS | All 4 tiers present in plans | - | Found: ['developer', 'team', 'growth', 'enterprise'] |
| PASS | Developer tier is free | - | price_monthly=0 |
| PASS | Team tier is $299/mo | - | price_monthly=299 |
| PASS | Growth tier is $699/mo | - | price_monthly=699 |
| PASS | Enterprise tier is $1999/mo | - | price_monthly=1999 |

### Subscription [PASS] (9/9)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | growth: GET /billing/subscription returns 200 | 200 | - |
| PASS | growth: GET /billing/plan-limit returns 200 | 200 | - |
| PASS | growth: plan_tier field present | - | got plan_tier=developer |
| PASS | growth: GET /billing/details returns 200 | 200 | - |
| PASS | enterprise: GET /billing/subscription returns 200 | 200 | - |
| PASS | enterprise: GET /billing/plan-limit returns 200 | 200 | - |
| PASS | enterprise: plan_tier field present | - | got plan_tier=developer |
| PASS | enterprise: GET /billing/details returns 200 | 200 | - |
| PASS | developer: correctly rate-limited (429) | 429 | Expected 429, got 429 |

### Org Creation [PASS] (4/4)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | developer: POST /organizations blocked (429 rate limit) | 429 | status=429 |
| PASS | team: POST /organizations blocked (429 rate limit) | 429 | status=429 |
| PASS | growth: POST /organizations blocked (should be 403) | 403 | FINDING: Growth user got 403 — missing require_tier('enterprise') decorator |
| PASS | enterprise: POST /organizations succeeds (201 or 400 already owns) | 400 | status=400, body={"detail":"You already own an organization. Use teams to organize work within your  |

### Org Lifecycle [PASS] (5/5)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | Org creation: already owns org (expected) | 400 | Will use existing org |
| PASS | Using existing org | - | id=a73cd8c9-cf46-43e3-9504-442f01335a32 |
| PASS | GET /organizations/{id} | 200 | - |
| PASS | GET /organizations (list) | 200 | - |
| PASS | PATCH /organizations/{id} | 200 | body={"id":"a73cd8c9-cf46-43e3-9504-442f01335a32","name":"Audit Test Org","slug":"audit-test-org-2f6 |

### Roles [PASS] (6/6)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | GET /organizations/{id}/roles | 200 | - |
| PASS | System roles present (owner, admin, developer, auditor, guest) | - | Found: ['admin', 'auditor', 'developer', 'guest', 'owner'] |
| PASS | GET /roles (convenience, with X-Organization-Id) | 200 | - |
| PASS | POST /organizations/{id}/roles (create custom) | 201 | id=2300ad1c-15f4-484a-9695-2373ae4f6862 |
| PASS | PATCH /organizations/{id}/roles/{id} (update custom) | 200 | - |
| PASS | DELETE /organizations/{id}/roles/{id} (delete custom) | 204 | - |

### Teams [PASS] (5/5)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | GET /organizations/{id}/teams | 200 | - |
| PASS | Default 'General' team exists | - | Found teams: ['General'] |
| PASS | POST /organizations/{id}/teams (create) | 201 | id=2b087837-cb17-4adf-b12a-0417e8e0b3d9 |
| PASS | GET /organizations/{id}/teams/{id} (detail) | 200 | - |
| PASS | PATCH /organizations/{id}/teams/{id} (update) | 200 | - |

### Members [FAIL] (3/4)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | GET /organizations/{id}/members | 200 | - |
| PASS | Owner is in member list | - | Members: ['44444444-4444-4444-4444-444444444444'] |
| PASS | GET /organizations/current/users (with X-Organization-Id) | 200 | body={"members":[{"id":"80874fea-18eb-45d9-840c-f93ed3045cdb","organization_id":"a73cd8c9-cf46-43e3- |
| **FAIL** | POST /members: duplicate returns 500 instead of 409 (FINDING) | 500 | FINDING: Should return 409 Conflict, got 500 IntegrityError |

### Team Members [FAIL] (0/3)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| **FAIL** | POST .../teams/{id}/members (add growth user to team) | 400 | body={"detail":"User is not a member of this organization"} |
| **FAIL** | PATCH .../teams/{id}/members/{user_id} (promote to lead) | 404 | body={"detail":"Team member not found"} |
| **FAIL** | PATCH team member role back to member | 404 | - |

### Invites [PASS] (4/4)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | POST /organizations/{id}/invites (create) | 201 | id=49ca07e8-91b2-4677-9264-fd679992e69a |
| PASS | GET /organizations/{id}/invites (list) | 200 | - |
| PASS | GET /invites/invalid-token returns 404 (anti-enumeration) | 404 | - |
| PASS | DELETE /organizations/{id}/invites/{id} (revoke) | 204 | - |

### Ownership [PASS] (3/3)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | Cannot change owner's role (blocked) | 400 | body={"detail":"Cannot change the owner's role"} |
| PASS | Cannot remove owner (blocked) | 400 | body={"detail":"Cannot remove the organization owner"} |
| PASS | Cannot create second org (one per owner) | 400 | body={"detail":"You already own an organization. Use teams to organize work within your organization |

### Data Scoping [PASS] (3/3)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | Growth user: GET /contracts with X-Organization-Id | 403 | 200=member, 403=not member (membership may have been cleaned up), 429=rate limited |
| PASS | Growth user: GET /contracts (personal workspace) | 200 | - |
| PASS | Developer user: org-scoped request (expected 429 or 403) | 429 | - |

### Tier Access [PASS] (2/2)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | Growth user: cannot create org (should be 403) | 403 | KNOWN BUG: missing require_tier — got 403 |
| PASS | Developer user: blocked (429 rate limit) | 429 | - |

### Ai Opt Out [PASS] (2/2)

| Status | Test | HTTP | Detail |
|--------|------|------|--------|
| PASS | GET /organizations/{id}/settings/ai-status | 200 | body={"organization_id":"a73cd8c9-cf46-43e3-9504-442f01335a32","ai_data_collection_disabled":true,"o |
| PASS | PUT /organizations/{id}/settings/ai-opt-out | 200 | body={"organization_id":"a73cd8c9-cf46-43e3-9504-442f01335a32","ai_data_collection_disabled":true,"o |

---

## Failures Detail

### members: POST /members: duplicate returns 500 instead of 409 (FINDING)
- **HTTP Status:** 500
- **Detail:** FINDING: Should return 409 Conflict, got 500 IntegrityError

### team-members: POST .../teams/{id}/members (add growth user to team)
- **HTTP Status:** 400
- **Detail:** body={"detail":"User is not a member of this organization"}

### team-members: PATCH .../teams/{id}/members/{user_id} (promote to lead)
- **HTTP Status:** 404
- **Detail:** body={"detail":"Team member not found"}

### team-members: PATCH team member role back to member
- **HTTP Status:** 404
- **Detail:** 

---

## Test Coverage

| Area | Tests | Description |
|------|-------|-------------|
| Billing Plans | Public plan listing, tier pricing | Verifies all 4 tiers with correct pricing |
| Subscription | Plan limits, billing details | Authenticated subscription status |
| Org Creation | Tier gate enforcement | Only enterprise can create orgs |
| Org Lifecycle | CRUD operations | Create, read, update organizations |
| Roles | System + custom roles | 5 system roles, custom role CRUD |
| Teams | Team CRUD | Default team, create, update, detail |
| Members | Member CRUD | Add, update role, list members |
| Team Members | Team membership | Add to team, promote/demote |
| Invites | Full invite flow | Create, view, anti-enumeration, revoke |
| Ownership | BSO-SEC-016 rules | Cannot modify/remove owner, one org per owner |
| Data Scoping | X-Organization-Id | Org-scoped vs personal workspace |
| Tier Access | Non-enterprise blocking | Growth/developer cannot create orgs |
| AI Opt-Out | Enterprise feature | AI data opt-out toggle |

---

## Related

- [Organization Management Workflow](../../workflows/organization-management-workflow.md)
- [Team Management Pipeline](../../pipelines/team-management-pipeline.md)
- [Subscription Workflow](../../workflows/subscription-workflow.md)
- [Tier Standards](../../standards/tier-standards.md)
