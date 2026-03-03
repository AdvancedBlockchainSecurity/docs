# RCA: Scanner Triggering Failure — 503 Service Unavailable

**Date:** 2026-03-03
**Duration:** Unknown onset — resolved at ~20:28 UTC
**Severity:** P1 — All scan operations blocked
**Status:** Resolved

---

## Summary

All scan triggers returned `503 Service Unavailable` because the tool-integration service rejected requests from the API service with `403 Forbidden`. The root cause was a stale `INTERNAL_SERVICE_TOKEN` in the live tool-integration ConfigMap that did not match the API service's `internal_service_key`.

---

## Timeline

| Time (UTC) | Event |
|---|---|
| 2026-02-26 | PR #115 merged to `main`: security hardening added `INTERNAL_SERVICE_TOKEN: "blocksecops-local-token"` to `configmap-patch.yaml` |
| 2026-02-26 — 2026-03-03 | Multiple version bumps (0.5.9 → 0.5.16) with `docker build` + `docker push` + image tag updates, but **no `kubectl apply -k`** was run against the tool-integration overlay |
| 2026-03-03 ~20:18 | User attempts scan on contract `58e8f036-fd9e-4916-bf80-7cd2a289bac1` |
| 2026-03-03 ~20:18 | API service triggers slither, aderyn, semgrep scanners → all return `403 Forbidden` |
| 2026-03-03 ~20:18 | After 3 consecutive 403s, API aborts scan with `503 Service Unavailable` |
| 2026-03-03 ~20:21 | `kubectl apply -k k8s/overlays/local/` run — ConfigMap updated |
| 2026-03-03 ~20:21 | `kubectl rollout restart deployment/tool-integration` — pods restarted with correct token |
| 2026-03-03 ~20:28 | Rollout complete, service restored |

---

## Root Cause

**Inter-service authentication token mismatch** between the API service and the tool-integration service.

### How scan triggering works

```
User → Dashboard → API Service (POST /api/v1/scans)
                       │
                       ▼
              Tool-Integration Service (POST /scans/{id}/trigger?scanner=slither)
              Header: X-Internal-Service-Token: <token>
                       │
                       ▼
              Kubernetes Scanner Job (slither, aderyn, etc.)
```

The API service sends the `X-Internal-Service-Token` header with the value from its ConfigMap key `internal_service_key`. The tool-integration service validates this against its own ConfigMap key `INTERNAL_SERVICE_TOKEN`.

### The mismatch

| Service | ConfigMap Key | Live Value (before fix) | Expected Value |
|---|---|---|---|
| api-service | `internal_service_key` | `blocksecops-local-token` | — |
| tool-integration | `INTERNAL_SERVICE_TOKEN` | `local-dev-internal-service-key-change-in-production` | `blocksecops-local-token` |

The tool-integration ConfigMap in the cluster still had the **pre-security-hardening default** (`local-dev-internal-service-key-change-in-production`), while the Git source of truth had been updated to `blocksecops-local-token` in commit `3b6fe4c` (Feb 26).

### Why the tokens diverged

1. **Feb 26 (commit `3b6fe4c`):** PR #115 merged — added `INTERNAL_SERVICE_TOKEN: "blocksecops-local-token"` to the ConfigMap patch and added endpoint authentication middleware to tool-integration
2. **Feb 26 — Mar 3:** The Docker image was rebuilt and pushed multiple times (0.5.9 → 0.5.16), and the kustomization `newTag` was updated, but `kubectl apply -k` was **only run for the image tag change**, not for the full overlay
3. The tool-integration base ConfigMap (from the original deployment on Oct 2025) contained `INTERNAL_SERVICE_TOKEN: "local-dev-internal-service-key-change-in-production"`, and the kustomize patch with the corrected value was never applied

**In short:** The image was updated but the ConfigMap was not. The new image code now enforced token validation (added in the same PR), but the token in the live ConfigMap was still the old default.

---

## Impact

- **All scan operations** returned 503 for the affected period
- Scan `c110f2cd-ced3-40c7-8d97-57eccfcbe2e4` was marked as `failed` in the database
- The 3-consecutive-failure circuit breaker correctly prevented resource exhaustion
- No data loss — contract code and metadata were preserved
- No security impact — the 403 rejection was the correct behavior (invalid token)

---

## Resolution

1. Ran `kubectl apply -k k8s/overlays/local/` from `blocksecops-tool-integration` repo — this applied the corrected ConfigMap with `INTERNAL_SERVICE_TOKEN: "blocksecops-local-token"`
2. Ran `kubectl rollout restart deployment/tool-integration -n tool-integration-local` to ensure pods picked up the new ConfigMap values
3. Verified ConfigMap value matches: `kubectl get configmap -n tool-integration-local tool-integration-config -o jsonpath='{.data.INTERNAL_SERVICE_TOKEN}'` → `blocksecops-local-token`

---

## Contributing Factors

1. **No automated ConfigMap drift detection.** The cluster ConfigMap diverged from Git with no alert.
2. **Partial kustomize apply.** Version bumps updated the image tag but didn't reapply the full overlay. The standard says "ALWAYS run `kubectl apply -k` after version bump" (Rule 5), but this was not enforced.
3. **Auth enforcement added in same PR as token value change.** PR #115 both added the authentication middleware AND set the correct token value. If either the ConfigMap or the image was stale, the service would break.
4. **No integration test for inter-service auth.** The health endpoint (`GET /health`) continued to pass (no auth required), masking the broken scan trigger path.

---

## Action Items

| # | Action | Priority | Owner |
|---|---|---|---|
| 1 | **Add ConfigMap drift detection.** CI/CD job or CronJob that compares live ConfigMap values against Git source of truth and alerts on mismatch. | P1 | Platform |
| 2 | **Enforce full `kubectl apply -k` on every deploy.** Update deploy scripts/Makefile to always apply the complete overlay, not just the image tag. | P1 | Platform |
| 3 | **Add inter-service auth integration test.** Smoke test that verifies API service can successfully POST to tool-integration `/scans/{id}/trigger` with a valid token after each deploy. | P2 | Backend |
| 4 | **Add readiness check for auth.** Tool-integration readiness probe should verify it can validate a service token (not just respond to `/health`). | P3 | Backend |
| 5 | **Mark failed scan as retriable.** Scan `c110f2cd` was marked `failed` due to infrastructure, not code issues. Add a mechanism to auto-retry or allow manual retry of infra-failed scans. | P3 | Backend |

---

## Lessons Learned

- **ConfigMaps are not updated by image pulls.** Updating a Docker image tag in kustomization.yaml and applying it does NOT update ConfigMaps unless the full overlay is applied. This is a Kubernetes fundamental that must be enforced in deploy workflows.
- **Adding authentication and setting credentials should be separate, ordered operations.** The security hardening PR coupled "enforce auth" with "set auth token" — if either side was stale, all requests would fail. A safer approach: deploy the credential first, verify it's live, then deploy the enforcement.
- **Circuit breakers work.** The 3-consecutive-failure abort in the scan endpoint prevented unbounded retries and resource exhaustion. This was a correct design decision.
