# Migration 091 — Pre-compiled contract artifacts

**Status:** Applied (production)
**Date applied:** 2026-05-11
**Alembic revision file:** `blocksecops-api-service/alembic/versions/20260509_2200-091_add_contract_artifacts.py`
**Author:** Apogee Team
**Related work:** [pipeline](../../pipelines/artifact-aware-scan-dispatch.md), [end-user workflow](../../workflows/contract-with-artifacts-upload.md), [troubleshooting playbook](../../playbooks/troubleshoot-fuzzer-zero-findings.md)

---

## Why

Halmos, Echidna, Medusa, and Trident depend on **pre-compiled build outputs** (Foundry `out/`, Hardhat `artifacts/`, Anchor `target/idl/`). Before this migration, the scanner pod re-compiled from source on the cluster — a missing dependency (e.g., `forge-std`) would silently fail the build and the scanner would return **0 findings** on a vulnerable project. Migration 091 lets users opt in to storing the artifacts they pre-compiled locally so the scanner can skip its build step.

---

## Schema changes (additive only)

Per `docs/standards/database-management.md`: this migration is additive, has CHECK constraints, has a clean downgrade path, and contains no destructive ALTERs.

### `contracts` table — two new columns

| Column | Type | Default | Why |
|---|---|---|---|
| `has_compiled_artifacts` | `BOOLEAN NOT NULL` | `false` | flag the dashboard reads to render the "Pre-compiled ✓" chip; the scan-dispatch path also reads it to decide whether to attach an artifact manifest to the tool-integration request |
| `artifact_layout` | `VARCHAR(32) NULL` | `NULL` | one of `foundry-out`, `hardhat-artifacts`, `anchor-target`; `NULL` when `has_compiled_artifacts = false` |

Both columns are additive. Existing rows are left at the default (`false` / `NULL`) — no backfill required.

### New `contract_artifacts` table

```sql
CREATE TABLE contract_artifacts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contract_id     UUID NOT NULL REFERENCES contracts(id) ON DELETE CASCADE,
    artifact_path   VARCHAR(500) NOT NULL,
    artifact_kind   VARCHAR(32)  NOT NULL,
    storage_kind    VARCHAR(8)   NOT NULL,
    storage_uri     VARCHAR(500),
    inline_content  BYTEA,
    size_bytes      INTEGER      NOT NULL,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX idx_contract_artifacts_contract_id_kind
    ON contract_artifacts(contract_id, artifact_kind);

-- Per-row invariant: exactly one of (inline_content, storage_uri) is populated.
ALTER TABLE contract_artifacts
    ADD CONSTRAINT contract_artifacts_storage_exclusive_check
    CHECK (
        (storage_kind = 'inline' AND inline_content IS NOT NULL AND storage_uri IS NULL)
     OR (storage_kind = 'gcs'    AND storage_uri    IS NOT NULL AND inline_content IS NULL)
    );

ALTER TABLE contract_artifacts
    ADD CONSTRAINT contract_artifacts_kind_check
    CHECK (artifact_kind IN ('foundry-out', 'hardhat-artifacts', 'anchor-target'));

ALTER TABLE contract_artifacts
    ADD CONSTRAINT contract_artifacts_storage_kind_check
    CHECK (storage_kind IN ('inline', 'gcs'));

ALTER TABLE contract_artifacts
    ADD CONSTRAINT contract_artifacts_size_nonneg_check
    CHECK (size_bytes >= 0);
```

`ON DELETE CASCADE` on `contract_id` is required because GDPR delete-account flows already cascade through `contracts → scans → vulnerabilities` and the artifact rows must follow.

### Hybrid storage policy

| Artifact size | Storage |
|---|---|
| `< 100 KiB` | `storage_kind='inline'`, bytes in `inline_content` (BYTEA) |
| `>= 100 KiB` | `storage_kind='gcs'`, URI in `storage_uri` (`gs://apogee-{env}-contract-artifacts/{contract_id}/{kind}/{path}`) |

Small artifacts stay co-located with the row for atomic delete + replication. Large ones go to GCS to keep Postgres small.

---

## How the migration was applied

The migration shipped in api-service 0.44.0. On 2026-05-11 it was applied via a transactional psql session because the not-yet-rolled api-service image didn't yet contain the alembic revision file:

```bash
# Backup first (per docs/standards/database-management.md).
kubectl exec -n postgresql-prod postgresql-0 -- pg_dump -U blocksecops solidity_security \
    -F c -f /tmp/pre-091-backup.sqlc
kubectl cp postgresql-prod/postgresql-0:/tmp/pre-091-backup.sqlc \
    ./pre-091-backup-20260511.sqlc

# Apply migration transactionally.
kubectl exec -n postgresql-prod postgresql-0 -- \
    psql -U blocksecops -d solidity_security -1 -f /tmp/migration-091.sql

# Verify alembic_version table advanced.
kubectl exec -n postgresql-prod postgresql-0 -- \
    psql -U blocksecops -d solidity_security \
    -c "SELECT version_num FROM alembic_version;"
# Expected: 091
```

The SQL is identical to what Alembic emits — once the api-service image bake catches up, the `alembic_version` row already says `091` so the migration is a no-op.

---

## Downgrade

`alembic downgrade -1` is supported. It drops the new table and the two new columns. CASCADE is **not** used on column drop because the columns are not referenced anywhere else.

```python
def downgrade() -> None:
    op.drop_index('idx_contract_artifacts_contract_id_kind', table_name='contract_artifacts')
    op.drop_table('contract_artifacts')
    op.drop_column('contracts', 'artifact_layout')
    op.drop_column('contracts', 'has_compiled_artifacts')
```

Tested locally on 2026-05-11 against a fresh clone of the production DB.

---

## Indexes

| Index | Purpose |
|---|---|
| `idx_contract_artifacts_contract_id_kind` | covers the dispatch-time query `SELECT * FROM contract_artifacts WHERE contract_id = $1 ORDER BY artifact_path`; the (contract_id, artifact_kind) composite supports future per-kind filtering |

The implicit `contract_id` FK also has its standard index. No additional indexes on `contracts.has_compiled_artifacts` or `artifact_layout` because the dashboard reads them by-contract-id only — never by these columns directly.

---

## Limits enforced by api-service

These are upstream (api-service) limits, not DB-level constraints:

| Limit | Value | Where enforced |
|---|---|---|
| Total artifact bytes per upload | 200 MB | `ArchiveExtractor._collect_build_artifacts` raises `ValueError` → HTTP 413 |
| Per-artifact file size | 10 MB | same |
| Total artifact file count | 5,000 | same |
| Allowed extensions in `out/` / `artifacts/` / `target/idl/` | `.json` only (`+.ts` for Anchor types) | `_collect_build_artifacts` uses `rglob("*.json")`; binaries silently filtered |

A row in `contract_artifacts` is only created after these checks pass.

---

## SCHEMA.md update

Per `docs/standards/database-management.md` Rule 4, `docs/database/SCHEMA.md` must be updated in the same commit as the migration. SCHEMA.md changes:

- Two new columns documented under the `contracts` table section
- New `contract_artifacts` table section with all 4 CHECK constraints, FK, and index
- Table count incremented from 87 → 88
- "Verified" date bumped to 2026-05-12

---

## Related production resources

- **GCS bucket:** `gs://apogee-production-contract-artifacts` (us-west1, 90-day lifecycle, uniform bucket-level access, public access prevention enforced)
- **API service GSA:** `apogee-api-service@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com` — bound `roles/storage.objectAdmin` on the bucket
- **Scanner GSA:** `apogee-tool-integration@project-8a2657b9-d96c-4c0a-a69.iam.gserviceaccount.com` — bound `roles/storage.objectViewer` on the bucket (read-only; least-privilege)
- **Workload Identity bindings:** K8s SA `api-service-prod/api-service` ↔ api-service GSA; K8s SA `tool-integration-prod/tool-integration` ↔ scanner GSA

Provisioned imperatively via `gcloud` 2026-05-11. Out of Terraform state — to be imported on the next infra-as-code pass.

---

## Verification queries

```sql
-- 1. Migration applied:
SELECT version_num FROM alembic_version;   -- expect: 091

-- 2. Columns on contracts:
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'contracts'
  AND column_name IN ('has_compiled_artifacts', 'artifact_layout');

-- 3. Constraints on contract_artifacts:
SELECT con.conname, con.contype, pg_get_constraintdef(con.oid)
FROM pg_constraint con
JOIN pg_class rel ON con.conrelid = rel.oid
WHERE rel.relname = 'contract_artifacts'
ORDER BY con.conname;

-- 4. Sample row from a known artifact-aware contract:
SELECT contract_id, artifact_path, artifact_kind, storage_kind, size_bytes
FROM contract_artifacts
WHERE contract_id = '86205bd5-f436-432f-b23e-c253bdcf83b3'   -- halmos-buggybank-v6-pure
LIMIT 5;
```
