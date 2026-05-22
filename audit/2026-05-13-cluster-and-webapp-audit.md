# Apogee Cluster & Web App Audit — 2026-05-13

**Date:** 2026-05-13
**Scope:** GKE production cluster (`project-8a2657b9-d96c-4c0a-a69`, 2-node `apogee-production` pool) + web application (`app.0xapogee.com`) — surface active errors and outstanding items needing attention.
**Trigger:** Owner request to scan for "errors, applications that we need to address" referencing `docs/`, `TaskDocs-BlockSecOps/`, and git history.
**Outcome:** Cluster is broadly healthy. **One active P0 was found** (`notification-prod` WebSocket auth broken — every WS connect from the dashboard is rejected). The rest is deferred / hygiene work already tracked in May 2026 TaskDocs audits.
**Action status:** Findings recorded 2026-05-13. **F1 fixed and verified live 2026-05-22** — see [`TaskDocs-BlockSecOps/audit-2026-05-22-notification-jwt-env-wiring.md`](../../TaskDocs-BlockSecOps/audit-2026-05-22-notification-jwt-env-wiring.md). F2–F7 remain deferred.

---

## Method

Read-only checks executed against the live cluster and HTTP endpoints. No `kubectl edit`, no apply, no rollout restart, no port-forwards (per `feedback_no_port_forward`).

**Cluster:**
- `kubectl get nodes -o wide`
- `kubectl get ns`
- `kubectl get pods -A -o wide`
- `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded`
- `kubectl get events -A --sort-by='.lastTimestamp'` (and `--field-selector type=Warning`)
- `kubectl describe pod` for restarted pods + `kubectl logs --previous`
- `kubectl logs -n <ns> deployment/<app> --since=2h | grep -iE 'error|exception|warn|rejected'` across the nine application namespaces
- `kubectl get certificate,gateway,httproute,pvc -A`
- `kubectl top pod -A` (metrics-server)
- Alertmanager API: `kubectl exec -n gmp-system alertmanager-0 -c alertmanager -- wget -q -O - http://localhost:9093/api/v2/alerts`

**Secrets / config drift:**
- `kubectl get secret -n notification-prod notification-secrets -o jsonpath='{.data}'` → key list (no values printed)
- Byte-length checks on suspect keys (`base64 -d | wc -c`) — values confirmed non-empty, never decoded to plaintext

**Web app:**
- `curl -sI https://app.0xapogee.com/`, `/admin/`, `/api/v1/scanners`
- TLS validity, response time, HTTP status

**Docs / history:**
- `TaskDocs-BlockSecOps/` May 2026 audit docs — "Out of scope / deferred" + "Bugs / regressions found" sections
- `git log --since='2026-04-29'` across the nine platform repos for `fix:|hotfix:|WIP|revert` commit messages
- Stale-branch enumeration across `/home/pwner/Git/blocksecops-*`

---

## Findings

### P0 — Active customer-facing bug

#### F1. `notification-prod` WebSocket auth broken — every dashboard WS connect rejected — **RESOLVED 2026-05-22**

**Status:** Fixed and verified live 2026-05-22. Wired `SUPABASE_JWT_SECRET` and `INTERNAL_SERVICE_TOKEN` env entries into `blocksecops-notification/k8s/base/deployment.yaml`, applied via `kubectl apply -k k8s/overlays/gcp/`. Added `TestNotificationEnvWiring` regression test class. Verified end-to-end via a direct WS bad-JWT probe — pod now logs `JWT validation failed: Signature verification failed` (correct path) instead of the env-empty rejection. Full execution detail in [`TaskDocs-BlockSecOps/audit-2026-05-22-notification-jwt-env-wiring.md`](../../TaskDocs-BlockSecOps/audit-2026-05-22-notification-jwt-env-wiring.md).

**Symptom (live log lines captured 2026-05-13 20:49–20:50 UTC):**
```
2026-05-13 20:49:28,893 - src.routes.websocket - ERROR -
  SUPABASE_JWT_SECRET not configured — rejecting WebSocket connection
2026-05-13 20:49:28,893 - src.routes.websocket - WARNING -
  Client sent invalid JWT token
2026-05-13 20:50:41,813 - src.routes.websocket - ERROR -
  SUPABASE_JWT_SECRET not configured — rejecting WebSocket connection
```
Errors are repeating on every WS connect attempt. Dashboard establishes the TCP/WS upgrade (`INFO: 35.191.x.x:NNNNN - "WebSocket /ws" [accepted]`), then notification rejects the JWT challenge and disconnects.

**Root cause — config drift between Secret and Deployment:**

1. `notification-prod/notification-secrets` (Opaque, age 64d) contains six keys:
   ```
   ['INTERNAL_SERVICE_TOKEN', 'SUPABASE_JWT_SECRET', 'database_url',
    'redis_url', 'smtp_host', 'smtp_password']
   ```
2. The keys are populated correctly by `ExternalSecret` (`blocksecops-notification/k8s/overlays/gcp/externalsecret.yaml` lines 25–30) from GCP Secret Manager (`apogee-gcp-jwt-secret`, `apogee-gcp-internal-service-key`).
3. Byte-length check confirms non-empty values: `SUPABASE_JWT_SECRET=64 B`, `INTERNAL_SERVICE_TOKEN=43 B`.
4. **But neither base nor overlay declares an `env` entry mapping those secret keys into the container.**
   - `blocksecops-notification/k8s/base/deployment.yaml:42-104` declares `REDIS_URL`, `DATABASE_URL`, `SMTP_HOST`, `SMTP_USER`, `SMTP_PASSWORD`, `SLACK_WEBHOOK_URL`, `DISCORD_WEBHOOK_URL`, plus configmap entries — **no `SUPABASE_JWT_SECRET`, no `INTERNAL_SERVICE_TOKEN`.**
   - `blocksecops-notification/k8s/overlays/gcp/deployment-patch.yaml` does not add them either.
5. Code reads the missing env at `blocksecops-notification/src/routes/websocket.py:252`:
   ```python
   supabase_jwt_secret = os.environ.get("SUPABASE_JWT_SECRET", "")
   if not supabase_jwt_secret:
       logger.error("SUPABASE_JWT_SECRET not configured — rejecting WebSocket connection")
   ```
6. `INTERNAL_SERVICE_TOKEN` likely needed for internal service-to-service WS auth (per commit `6320150 security: add internal service auth, restrict broadcast to authenticated connections (#39)`) — same missing-wire pattern.

**Is the code path live?** Yes — verified:
- Dashboard still uses Supabase: `blocksecops-dashboard/src/lib/supabase.ts:9-20` imports `@supabase/supabase-js` and creates a client from `VITE_SUPABASE_URL` / `VITE_SUPABASE_ANON_KEY`. `client.ts:61` reads `await supabase.auth.getSession()` before every API call.
- api-service still uses Supabase: `blocksecops-api-service/src/presentation/api/v1/endpoints/wallet_auth.py:36-39,204-233` for wallet→Supabase user linking.

This is not dead code; the WebSocket rejection is hitting real customers (and the owner's test account `jasonbrailowbizop@mail.com` whenever the dashboard is open).

**Impact:**
- Real-time notifications (scan progress, scan completion, vulnerability alerts) do not reach the dashboard.
- HTTP-polling fallbacks may mask the symptom partially — owner should validate whether scan-status updates appear without page refresh.

**Recommended remediation (not executed this pass):**
- Edit `blocksecops-notification/k8s/base/deployment.yaml`, append two `env` entries after the `SMTP_PASSWORD` block (lines 80–84):
  ```yaml
  - name: SUPABASE_JWT_SECRET
    valueFrom:
      secretKeyRef:
        name: notification-secrets
        key: SUPABASE_JWT_SECRET
  - name: INTERNAL_SERVICE_TOKEN
    valueFrom:
      secretKeyRef:
        name: notification-secrets
        key: INTERNAL_SERVICE_TOKEN
  ```
- No image rebuild required (source code already reads these env vars). Per `docs/standards/docker-image-versioning.md`, this is a deploy-config-only change.
- Apply via `kubectl apply -k blocksecops-notification/k8s/overlays/gcp/`, wait for rollout, verify with `kubectl logs -n notification-prod deploy/notification --since=2m | grep -c "SUPABASE_JWT_SECRET not configured"` returning `0`.
- Owner-driven browser check: open dashboard, confirm WS connects without rejection log line.

**Approval gate per `feedback_rule0_gitops`:** all three actions (commit, apply, rollout) require fresh explicit owner approval — not pre-authorized by reading this doc.

---

### P1 — Deferred / hygiene items already on record

#### F2. Terraform import of Migration 091 GCP resources

Per `TaskDocs-BlockSecOps/audit-2026-05-12-migration-091-precompiled-artifacts.md:172-181`:
- GCS bucket `gs://apogee-production-contract-artifacts` (us-west1, 90-day lifecycle, uniform bucket-level access)
- GSA `apogee-api-service@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com` (bucket `roles/storage.objectAdmin`)
- GSA `apogee-tool-integration@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com` (bucket `roles/storage.objectViewer`)
- 2× Workload Identity bindings (api-service-prod/api-service, tool-integration-prod/tool-integration)

All provisioned imperatively via `gcloud` on 2026-05-11. **Not yet imported into Terraform state.**

**Risk if ignored:** next `terraform plan` reports these as missing-state-but-existing-in-cloud and may propose to delete-and-recreate; an `apply` without `terraform import` first would risk data loss on the bucket.

**Not blocking until the next infra-as-code pass.**

#### F3. Stale `production/` overlay in `blocksecops-tool-integration`

Per `TaskDocs-BlockSecOps/audit-2026-05-07-solhint-p02-severity-fix.md`:
- `blocksecops-tool-integration/k8s/overlays/production/` references namespace `blocksecops` which no longer exists (live deployment uses `tool-integration-prod` via `k8s/overlays/gcp/`).
- Two orphan cluster-scoped resources exist: `ClusterRole` and `ClusterRoleBinding` named `prod-tool-integration-cluster-reader` — not bound to any pod.

**Impact:** cosmetic. Not actively harming the cluster but indicates branch drift. Either delete the overlay directory and the orphan RBAC, or sync the overlay's namespace + resources with the live `gcp/` overlay.

#### F4. Anchor + Trident E2E for Migration 091 not run

Per `TaskDocs-BlockSecOps/audit-2026-05-12-migration-091-precompiled-artifacts.md:41,201`. Verification row #6 was deferred because no local Anchor toolchain is installed. Foundry and Hardhat code paths verified clean; Anchor path is "implied but not proven".

**Per `feedback_local_not_gcp`,** the fix is to install Anchor CLI on this workstation and run the local E2E with an Anchor fixture (`scanner-trident` parses `target/idl/<program>.json`). No cluster action needed.

---

### P2 — Nice-to-have

#### F5. `contracts.compiler_version` backfill for historical rows

Per `TaskDocs-BlockSecOps/audit-2026-05-12-scanner-matrix-regression.md:84-90`. `TestA-VulnGood-0.8.20` and likely other contracts uploaded before `language_detector.py` populated `compiler_version` carry NULL in the DB. The api-service pragma-gate pre-dispatch optimization skips for NULL rows; the wrapper-side `check-pragma` gate still catches it at scanner-Job time, so behavior is correct, just unoptimized.

#### F6. Foundry → crytic-compile JSON-format shim

Per `TaskDocs-BlockSecOps/audit-2026-05-12-migration-091-precompiled-artifacts.md:204`. echidna 0.5.7 / medusa 0.5.2 gate `--ignore-compile` on `hardhat-artifacts` layout only. Foundry-layout scans recompile from source — works fine because the artifact-stager bundles `lib/forge-std` and test files, so `forge build` succeeds in-pod. Pure performance enhancement (save the recompile time).

#### F7. Stale unmerged branches across multiple repos

Branches seen via `git branch -a --no-merged main`:
- `blocksecops-api-service`: `feat/api-service-github-app-byo`
- `blocksecops-dashboard`: `feat/dashboard-github-app-byo-wizard`, `chore/dashboard-0.49.0-csp-and-github-tab`
- `blocksecops-admin-portal`: `feat/align-dashboard-styling`, `fix/kustomize-source-of-truth`
- `blocksecops-data-service`, `blocksecops-intelligence-engine`, `blocksecops-notification`: `security/phase-6-comprehensive-audit`
- `blocksecops-data-service`: `fix/worker-asyncpg-nullpool`, `feat/celery-ml-tasks`
- `blocksecops-docs`, `blocksecops-shared`: `chore/apogee-rebrand`

Triage required: resume or delete. Some are 4+ weeks old and the platform shipped Migration 091 on `main` since then.

---

## Verified clean (no action needed — baseline for next audit)

### Cluster

- **Nodes:** 2× `gke-apogee-productio-apogee-productio-91064ee3-{c06e,sx21}` Ready, K8s `v1.35.3-gke.1389000`, COS, containerd 2.1.5. (A 3rd ephemeral node `e56b1194-fqvp` appeared briefly during audit — autoscaler reacting to scanner Jobs; expected.)
- **Pods:** All 62 in `Running`/`Completed`. No `Failed`, `Evicted`, `CrashLoopBackOff`, or `Pending` (other than transient gmp `collector` on new node).
- **Restarts:** Two pods with `RESTARTS=1 (3d8h ago)` — both single transient events, recovered:
  - `data-service-9dfc6cdc9-5np5q`: exit code 0 = normal rolling-update / liveness restart.
  - `notification-7ddf5fb6cb-mlbzs`: exit code 137 (SIGKILL) from a 2026-05-10 06:22 UTC Redis `ConnectionError: Error 111 connecting to redis.redis-prod.svc.cluster.local:6379`. Redis recovered, pod restarted clean.
- **Warning events:** none in `kubectl get events -A --field-selector type=Warning`.
- **PVCs:** all `Bound` (`postgresql-data`, `postgresql-backup`, `redis-data`).
- **TLS certificates:** all `Ready=True` (cert-manager, postgresql-tls, redis-tls).
- **Ingress:** `Gateway/apogee-gateway` Programmed; `HTTPRoute/{apogee-routes, admin-routes, http-redirect}` all object references resolved.
- **Memory pressure:** all platform pods <100 MiB, none at >85% of limit.
- **Alertmanager:** empty alert list.

### Web app

- `curl -sI https://app.0xapogee.com/` → 200, TLS valid.
- `https://app.0xapogee.com/admin/` → 200.
- `https://app.0xapogee.com/api/v1/scanners` → 200, returns 17 production-ready scanners.

### Scanner correctness

- **17/17 scanners at baseline counts** per `TaskDocs-BlockSecOps/audit-2026-05-12-scanner-matrix-regression.md`:
  slither, aderyn, semgrep, solhint, mythril, wake, soliditydefend, halmos, medusa, echidna, vyper, moccasin, sol-azy, rustdefend, sec3-xray, trident, cargo-fuzz-solana.
- Pragma gate correctly fast-fails `^0.8.0` contracts synchronously without dispatching scanner Jobs (compute savings preserved).
- Migration 091 customer path verified: halmos+Foundry-artifacts → critical=1; echidna+Hardhat-artifacts → high=1.

### PostgreSQL backup cron

- `postgresql-backup-29642520-6fwkr` (42h ago) — Completed.
- `postgresql-backup-29643960-nhsww` (18h ago) — Completed.
- `pre-091-backup-20260511-201122-49qqm` (2d ago) — Completed (the Migration 091 pre-flight backup).

### Recent commit hygiene

- `git log --since='2026-04-29' --oneline` across the nine platform repos: zero commits matching `revert`, `WIP`, `TODO`; the `fix:` commits are all post-mortem fixes from Migration 091 execution (NetworkPolicy for WI metadata, jq→python3 switch, GCS pairs encoding, halmos parser envelope, echidna parser schema, etc.) — all documented in `audit-2026-05-12-migration-091-precompiled-artifacts.md` and already shipped.

---

## References

### TaskDocs cited

- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-04-scanner-full-reaudit.md`
- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-05-wake-target-version-regression.md`
- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-06-scanner-failure-fixes.md`
- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-07-solhint-p02-severity-fix.md`
- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-12-migration-091-precompiled-artifacts.md`
- `/home/pwner/Git/TaskDocs-BlockSecOps/audit-2026-05-12-scanner-matrix-regression.md`

### Code paths cited (for the P0)

- `/home/pwner/Git/blocksecops-notification/src/routes/websocket.py:252-259` — empty-env rejection
- `/home/pwner/Git/blocksecops-notification/k8s/base/deployment.yaml:42-104` — env block missing SUPABASE_JWT_SECRET / INTERNAL_SERVICE_TOKEN
- `/home/pwner/Git/blocksecops-notification/k8s/overlays/gcp/deployment-patch.yaml` — strategic merge patch, also does not add them
- `/home/pwner/Git/blocksecops-notification/k8s/overlays/gcp/externalsecret.yaml:25-30` — correctly populates the secret keys from GCP Secret Manager
- `/home/pwner/Git/blocksecops-dashboard/src/lib/supabase.ts:9-20` — Supabase client still in use
- `/home/pwner/Git/blocksecops-dashboard/src/lib/api/client.ts:61` — `supabase.auth.getSession()` on every API call
- `/home/pwner/Git/blocksecops-api-service/src/presentation/api/v1/endpoints/wallet_auth.py:204-233` — wallet→Supabase user linking

### Standards consulted

- `docs/standards/docker-image-versioning.md` — manifest-only changes don't require image SemVer bump
- `docs/standards/kustomize-standards.md` — base stays environment-neutral; overlays carry env-specific config
- `docs/standards/service-availability.md` — all checks went through `app.0xapogee.com`, no port-forwards
- `feedback_rule0_gitops` — fresh approval for each GitOps step
- `feedback_no_port_forward` — read-only kubectl only
- `feedback_local_not_gcp` — Anchor E2E gap is a local-toolchain install, not a cluster task

---

## Next action

Owner decides priority of F1. If F1 is approved for remediation, that becomes a separate plan with a fresh per-step GitOps approval gate per `feedback_gitops_each_step_approval`. F2–F7 remain logged here until separately prioritized.
