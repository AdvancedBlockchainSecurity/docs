# API Service v0.28.3 / v0.28.4 - Single Organization Ownership

## Version 0.28.3 - February 8, 2026

**Date:** 2026-02-08
**Component:** blocksecops-api-service (0.28.2 -> 0.28.3)
**Type:** Fix / Enhancement
**Priority:** High
**Status:** Complete

### Summary

Enforced single organization ownership per user. A test user owned 3 organizations due to a missing ownership check in `POST /organizations`. Since each organization maps to one subscription (one billing relationship), users should only own one active organization. Deactivated the 2 extra orgs and added a server-side check preventing duplicate ownership.

### Added

- **Single-ownership check** in `POST /api/v1/organizations`:
  - Queries for existing active organizations owned by the user
  - Returns 400 "You already own an organization. Use teams to organize work within your organization." if one exists
  - Deactivated orgs (`is_active = false`) do not count against the limit

- **Alembic migration 073** (`073_enforce_single_org_ownership`):
  - Soft-deletes "teste" and "Worm Org" organizations
  - Removes memberships for deactivated orgs
  - Sets `default_organization_id` for affected user
  - Database backup taken before migration: `docs/database/backups/solidity_security_pre_org_cleanup_20260208.sql`

### Code Changes

**Files Modified:**
- `src/presentation/api/v1/endpoints/organizations.py` — Added ownership check before org creation
- `alembic/versions/20260208_1000-073_enforce_single_org_ownership.py` — New migration

**Files Created:**
- `docs/database/backups/solidity_security_pre_org_cleanup_20260208.sql` — Pre-migration backup

### Deployment

```bash
cd /home/pwner/Git/blocksecops-api-service
docker build -t harbor.0xapogee.local/blocksecops/api-service:0.28.3 .
docker push harbor.0xapogee.local/blocksecops/api-service:0.28.3
kubectl apply -k k8s/overlays/local/api-service/
kubectl rollout restart deployment/api-service -n api-service-local

# Run migration inside pod
kubectl exec -n api-service-local deployment/api-service -- alembic upgrade head
```

---

## Version 0.28.4 - February 8, 2026

**Date:** 2026-02-08
**Component:** blocksecops-api-service (0.28.3 -> 0.28.4)
**Type:** Fix
**Priority:** High
**Status:** Complete

### Summary

Updated migration 073 to backfill org-scoped data. Migration 069 had skipped the affected user (owned 3 orgs at the time), leaving 76 contracts, 203 scans, and 4 projects with `organization_id = NULL`. These records were invisible under org-scoped queries.

### Changed

- **Migration 073 updated** with backfill statements:
  - `UPDATE contracts SET organization_id = ... WHERE user_id = ... AND organization_id IS NULL`
  - `UPDATE scans SET organization_id = ... WHERE user_id = ... AND organization_id IS NULL`
  - `UPDATE projects SET organization_id = ... WHERE user_id = ... AND organization_id IS NULL`

### Code Changes

**Files Modified:**
- `alembic/versions/20260208_1000-073_enforce_single_org_ownership.py` — Added backfill SQL
- `pyproject.toml` — Version 0.28.3 -> 0.28.4
- `k8s/overlays/local/api-service/kustomization.yaml` — newTag 0.28.3 -> 0.28.4

### Impact

- **User Impact:** All contracts, scans, and projects now visible under org context
- **Breaking Changes:** None
- **Data Impact:** 76 contracts, 203 scans, 4 projects assigned to "Test Organization"

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.28.4 | 2026-02-08 | Backfill org-scoped data in migration 073 |
| 0.28.3 | 2026-02-08 | Enforce single org ownership, deactivate duplicate orgs |
| 0.28.2 | 2026-02-07 | Security audit remediation |

---

## Related Documentation

- [Subscription Workflow](../workflows/subscription-workflow.md) — End-to-end subscription lifecycle
- [Subscription Pipeline](../pipelines/subscription-pipeline.md) — Technical Stripe/x402 pipeline
- [Organization Scoping Pipeline](../pipelines/organization-scoping-pipeline.md) — Org data isolation
- [Create Organization Playbook](../playbooks/create-organization.md) — Updated with ownership limit
- [Database Backups](../database/BACKUPS.md) — Pre-migration backup logged
- [Enterprise Features Tests](../feature-tests/14-enterprise-features.md) — Ownership test cases added

---

**Maintained By:** Apogee Team
**Status:** Complete
