# Playbook — Troubleshoot fuzzer / symbolic-execution scan reporting 0 findings

**Audience:** Apogee operations / customer-success
**Status:** active (Migration 091, 2026-05-09)
**Cross-links:** [End-user workflow](../workflows/contract-with-artifacts-upload.md), [Pipeline](../pipelines/artifact-aware-scan-dispatch.md)

---

## Symptom

A user runs **Halmos**, **Echidna**, **Medusa**, or **Trident** on a project they expect to be vulnerable, and the dashboard shows the scan as `completed` with **0 findings**. The user pushes back.

---

## Likely root causes (in priority order)

### 1. Fuzzer ran without pre-compiled artifacts and silently failed at compile

This is the failure mode that motivated Migration 091 (2026-05-09). Halmos / Echidna / Medusa depend on Foundry-style `out/` JSON or Hardhat `artifacts/`. Trident depends on `target/idl/`. Without them:

- Halmos hard-fails fast (visible exit code, error in `error_message`).
- Echidna & Medusa let crytic-compile attempt a `forge build` / `npx hardhat compile`. If `forge-std` / `@openzeppelin/contracts` aren't bundled, the build fails — but echidna's exit can still be 0 with empty findings. Note: as of echidna 0.5.7 / medusa 0.5.2 (2026-05-12) the `--ignore-compile` skip-compile path is **only** taken for `hardhat-artifacts` layout; `foundry-out` falls through to recompile from source because crytic-compile's hardhat-like parser raises `KeyError: 'output'` against Foundry's flat per-contract JSON. The api-service extractor now bundles `test/*.sol` alongside `src/` when `with_artifacts=true` so `forge build` has a complete tree.
- Trident's `anchor build` fails on missing Solana toolchain pieces.

**Diagnosis:**

```sql
SELECT id, name, has_compiled_artifacts, artifact_layout, framework
FROM contracts
WHERE id = '<contract_id>';
```

If `has_compiled_artifacts = false` and `framework IN ('foundry', 'hardhat', 'plain')`, this is almost certainly the cause.

**Fix:** Tell the customer to re-upload with the **"Include pre-compiled artifacts"** toggle enabled. Steps in the [end-user workflow doc](../workflows/contract-with-artifacts-upload.md). The contract-detail page also surfaces a soft amber warning on the scanner picker for this exact case.

---

### 2. Project has no `echidna_*` / `property_*` / `assert*` invariant tests

Echidna and Medusa only fire findings when the source contains harness functions (`echidna_*`, `property_*`, `crytic_*`, `assert*` patterns). A clean project with no harness legitimately scans to 0 — that's correct behavior, not a regression.

**Diagnosis:**

```sql
SELECT cf.file_path
FROM contract_files cf
WHERE cf.contract_id = '<contract_id>'
  AND cf.file_content ILIKE '%echidna_%';
```

(or `property_%`, `assert%` for medusa).

**Fix:** Tell the customer to add invariant tests, or to run static analyzers (Slither/Aderyn) instead, which find issues without harness.

---

### 3. Pre-compiled artifacts were uploaded but the GCS-backed ones weren't fetched into the pod

If `has_compiled_artifacts = true` but the scanner Job's `artifact-stager` initContainer logs show `gsutil` errors, the scanner GSA likely lacks `roles/storage.objectViewer` on the artifact bucket.

**Diagnosis:**

```bash
# Find the scanner pod for the failed scan
kubectl get pods -n tool-integration-prod -l scan-id=<scan_id>

# Inspect the artifact-stager initContainer logs
kubectl logs -n tool-integration-prod <pod_name> -c artifact-stager
```

If you see `AccessDeniedException: 403`, the binding is broken. If you see `BucketNotFoundException: 404`, the `ARTIFACT_BUCKET` env var is wrong.

**Fix:**

```bash
# Verify the binding (replace project + GSA email)
gcloud storage buckets get-iam-policy gs://apogee-production-contract-artifacts \
  --format='json' | jq '.bindings[] | select(.role == "roles/storage.objectViewer")'

# If the scanner GSA isn't listed:
gcloud storage buckets add-iam-policy-binding gs://apogee-production-contract-artifacts \
  --member='serviceAccount:tool-integration@<project>.iam.gserviceaccount.com' \
  --role='roles/storage.objectViewer'
```

Per [`secrets-management.md`](../standards/secrets-management.md): only Workload Identity, never service-account JSON keys.

---

### 4. Inline artifacts were dropped at validation due to malformed base64 / unsafe paths

`KubernetesJobManager._validate_artifact_manifest()` drops malformed entries with a warning instead of failing the dispatch. Look for these in the api-service or tool-integration logs:

```text
Dropping inline artifact with invalid base64
Dropping artifact with unsafe path
Dropping artifact with unknown kind
```

**Diagnosis:** correlate the log timestamps with the dispatch time of the failing scan. If the dispatched manifest had N entries but the artifact-stager landed only N-1 in `/contracts`, one was dropped.

**Fix:** file a bug — this should not happen for artifacts that were valid at upload time. Likely a bug in the dispatch payload encoding (api-service-side) or the initContainer's path validator (tool-integration-side).

---

### 5. The scanner timed out before discovering anything

Halmos's symbolic execution is slow on large codebases. The KJM `activeDeadlineSeconds` is per-scanner; if you exceed it, the pod is terminated mid-execution and the scan is marked completed with whatever was discovered (often 0).

**Diagnosis:**

```sql
SELECT id, started_at, completed_at, status, failure_type
FROM scanner_executions
WHERE scan_id = '<scan_id>' AND scanner = 'halmos';
```

If `completed_at - started_at` is exactly the per-scanner timeout, this is it.

**Fix:** unfortunately, today's deadline is hard-coded per scanner in `KubernetesJobManager._get_timeout_seconds`. If the customer needs more time, file a feature request (out of scope for this playbook).

---

## Quick decision tree

```
Scan reports 0 findings on Halmos / Echidna / Medusa / Trident
  ├── contracts.has_compiled_artifacts ?
  │     ├── false → cause #1 (re-upload with artifacts; confidence ~85%)
  │     └── true → continue
  │
  ├── source contains echidna_* / property_* / assert_ ?
  │     ├── no → cause #2 (correct behavior, no fix needed)
  │     └── yes → continue
  │
  ├── artifact-stager initContainer logs clean ?
  │     ├── no → cause #3 (GCS IAM) or #4 (validator drops)
  │     └── yes → continue
  │
  └── scanner_executions timing matches the per-scanner timeout ?
        ├── yes → cause #5 (timeout)
        └── no → file a bug (unknown failure mode)
```

---

## Mitigations we've shipped

- **Pre-compiled artifact upload (Migration 091, 2026-05-09 → follow-up 2026-05-12):** lets users opt in to bundling `out/`, `artifacts/`, `target/idl/` so the scanner pod skips its build step entirely. Eliminates causes #1 and #3 for users who use the feature.
- **Foundry source-bundle fix (api-service 0.44.1, 2026-05-12):** `_find_entry_files` now includes `test/*.sol` when `preserve_build_artifacts=True`. Without this, halmos/echidna/medusa couldn't see test contracts when the artifact-aware path was used, and forge's internal rebuild silently pruned the pre-loaded test artifact.
- **Parser/wrapper schema-drift fixes (tool-integration 0.7.3 / 0.7.5):** halmos parser now reads the wrapper's `findings` envelope; echidna parser accepts the 2026 `scanner+vulnerabilities` envelope (`locations[0].file`, top-level `call_sequence`). Both were pre-existing platform bugs that only surfaced once Migration 091 produced the first real findings end-to-end.
- **Echidna/Medusa Foundry-aware skip-compile (echidna 0.5.7, medusa 0.5.2):** `--ignore-compile` is no longer set for `foundry-out` layout (crytic-compile's hardhat-like parser can't read Foundry's flat per-contract JSON). Foundry-layout scans fall through to recompile from the bundled sources, eliminating a regression introduced by the original Migration 091 wrappers (0.5.6/0.5.1).
- **Soft warning in the scanner picker:** when a customer selects Halmos/Echidna/Medusa/Trident on a Source-only contract, the dashboard tells them to re-upload — they understand the risk before triggering the scan.
- **Anchor `target/deploy/` is intentionally rejected at upload time:** prevents customers from leaking program keypairs through the artifact channel.

---

## Standards & cross-references

- [`docs/standards/secure-coding.md`](../standards/secure-coding.md) — allow-list for artifacts, defense-in-depth path validation
- [`docs/standards/secrets-management.md`](../standards/secrets-management.md) — Workload Identity over JSON keys
- [`docs/standards/database-management.md`](../standards/database-management.md) — backup before any DB query that touches `contract_artifacts`
