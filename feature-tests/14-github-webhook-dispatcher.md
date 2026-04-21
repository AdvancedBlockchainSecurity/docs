# GitHub App Webhook Dispatcher Tests

**Priority**: P1 - High (security boundary)
**Last Tested**: April 21, 2026
**Endpoint**: `POST /api/v1/github-app/webhook`
**Upstream**: GitHub App per-installation webhook

---

## Background

When a customer's GitHub App fires a webhook to Apogee, the dispatcher:

1. Looks up the installation's credential to retrieve the per-installation webhook secret (Fernet-decrypted)
2. Verifies the `X-Hub-Signature-256` HMAC over the raw body (constant-time `hmac.compare_digest`)
3. Parses the event — only `push` and `pull_request` dispatch; other events (ping, installation, check_suite, …) are 204-acked
4. Enforces per-repo opt-in gates: `auto_scan_enabled`, and for push → `scan_on_push` AND ref == default branch; for PR → `scan_on_pr` AND action in `{opened, synchronize, reopened}`
5. Enqueues `sync_repo_contracts` Celery task — the same path as the UI "Sync now" button

Syncs are content-idempotent (same commit SHA → same result), so GitHub's retry behavior is safe without a dedicated dedup table.

**Out of scope** (tracked separately): dispatching scans automatically after sync. Today the sync imports contracts; customers scan manually. Keeps quota/tier enforcement in the existing `create_scan` flow.

---

## 1. Signature verification (OWASP A08)

### 1.1 Missing signature → 401
- [ ] POST a valid-shaped body with no `X-Hub-Signature-256` header → HTTP 401 `Invalid webhook signature`

### 1.2 Wrong signature → 401
- [ ] POST with `X-Hub-Signature-256: sha256=deadbeef...` and a real body → HTTP 401

### 1.3 Valid signature → dispatch
- [ ] Compute `sha256=<HMAC-SHA256(secret, body)>` using the installation's secret → HTTP 204 + `sync_repo_contracts` enqueued (verifiable in Celery dashboard / `logger.info` with `delivery_id`)

### 1.4 Malformed signature header → 401
- [ ] `X-Hub-Signature-256: md5=abcd...` (wrong algorithm prefix) → HTTP 401

### 1.5 Constant-time comparison
- [ ] Verified structurally in `tests/unit/presentation/test_github_webhook_dispatcher.py::TestHMACConstantTimeCompare::test_verify_uses_compare_digest`

---

## 2. Existence non-leak

### 2.1 Unknown installation.id → 204
- [ ] POST with `installation.id: 999999999` (non-existent) and any body → HTTP 204
- [ ] Logged as `installation_id unknown` but no error to the client (prevents installation-existence probing)

### 2.2 Known installation, unknown repository → 204
- [ ] POST with a real installation + `repository.id` that was never imported → HTTP 204
- [ ] No sync enqueued; logged as `repo not synced into Apogee`

---

## 3. Fail-safe paths (must NOT 5xx → GitHub retry storm)

Structurally verified in `TestWebhookFailSafePaths`:

- [ ] Malformed JSON body → 204 (logged as invalid JSON)
- [ ] Missing `installation.id` → 204 (treated as ping/meta event)
- [ ] Missing `repository.id` on a repo-scoped event → 204
- [ ] Event type not in `{push, pull_request}` (e.g., `ping`, `installation`, `check_suite`) → 204
- [ ] Webhook secret decryption fails (Fernet `InvalidToken`) → 204
- [ ] Credential has no resolvable org → 204

The ONLY 5xx path is when the Celery broker is down — we intentionally return 500 there so GitHub retries the delivery.

---

## 4. Per-event gates

### 4.1 Master switch off
- [ ] Repo with `auto_scan_enabled=false` → any valid event returns 204 without dispatch
- [ ] Logged as `auto_scan_enabled=false for repo`

### 4.2 Push to non-default branch
- [ ] Valid push event to `refs/heads/feature-x` with `default_branch: "main"` → 204
- [ ] Logged as `push to non-default branch`

### 4.3 Push with `scan_on_push=false`
- [ ] Valid push to default branch, `auto_scan_enabled=true`, `scan_on_push=false` → 204

### 4.4 PR with `scan_on_pr=false`
- [ ] PR `opened`, `auto_scan_enabled=true`, `scan_on_pr=false` → 204

### 4.5 PR action not in allowlist
- [ ] PR `action: closed` / `edited` / `labeled` / `review_requested` → 204 (only `opened`, `synchronize`, `reopened` dispatch)

### 4.6 All gates pass
- [ ] Push to `refs/heads/main`, `auto_scan_enabled=true`, `scan_on_push=true` → 204 + sync enqueued
- [ ] PR `opened`, `auto_scan_enabled=true`, `scan_on_pr=true` → 204 + sync enqueued
- [ ] `IntegrationRepositoryModel.sync_status` flips to `syncing` then `synced` with a new `last_synced_commit`

---

## 5. Idempotency

### 5.1 GitHub retry storm
- [ ] Simulate a retry: POST the same delivery 3× within 10s
- [ ] Each returns 204; 3 sync tasks enqueue
- [ ] Syncs run; all 3 produce the same `last_synced_commit` with `created=0 updated=0 skipped=0` (second and third runs are no-ops)
- [ ] No duplicate contracts created

---

## 6. Rate limiting

### 6.1 120/minute cap
- [ ] Send 200 requests in one minute → requests past 120 return HTTP 429

---

## 7. Live smoke tests

Done in production (2026-04-21) immediately after 0.43.0 deploy:

| Test | Expected | Actual |
|---|---|---|
| POST with unknown installation_id | 204 (non-leak) | ✅ 204 |
| POST with no installation.id (ping-style) | 204 | ✅ 204 |
| Auth regression — `GET /scans?limit=1` with fresh token | 200 | ✅ 200 |

A full valid-signature end-to-end test requires a real GitHub App installation + webhook secret; structural tests + the shipped dispatcher are sufficient. Customers can trigger webhook tests from `https://github.com/settings/apps/<app>/advanced` to exercise the live dispatch path.

---

## Related Tests

- **Unit coverage** (in `blocksecops-api-service`):
  - `tests/unit/presentation/test_github_webhook_dispatcher.py` — 28 tests covering stub-replacement, HMAC primitive (positive + 4 negative), signature-before-dispatch ordering, event whitelist, master + sub-flag gates, default-branch restriction, PR action allowlist, installation → credential → repo resolution, fail-safe paths (malformed JSON, missing installation.id / repository.id, unknown event, decrypt failure, orphan integration), enqueue contract, 401 / 500 / 204 status semantics, constant-time compare
- **Related**:
  - Task #152 feature-test (`13-auto-scan-opt-in.md`) — customers opt in via the flags this dispatcher reads
  - **By design, not a follow-up:** the dispatcher never auto-creates scans. Auto-dispatching scans on every push would burn a customer's quota on massive repos (one scan per `.sol` file). The opt-in flags gate sync only; scan-trigger stays a manual customer action via the dashboard Scan button.
