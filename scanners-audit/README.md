# Scanner Audit Tracking

**Status:** Active
**Last Updated:** 2026-05-06

## Files in this folder

- [`scanner-status.md`](./scanner-status.md) — current functional status of every scanner (one row per scanner)
- [`CHANGELOG.md`](./CHANGELOG.md) — reverse-chronological log of every scanner fix or status change

## How to use

1. Before fixing a scanner, read its row in `scanner-status.md` (current status, last-known-good baseline, fixture used, open issues).
2. After every fix attempt, update that row AND add a `CHANGELOG.md` entry — same commit.
3. Verify fixes against the production API as `jasonbrailowbizop@mail.com` (enterprise tier). Record the scan ID in the changelog entry.
4. Fix one scanner at a time. Don't pre-emptively fix scanners without cluster-verified evidence.

## Standards

All work in this folder must follow:

- [`../standards/documentation-standards.md`](../standards/documentation-standards.md)
- [`../standards/version-control-standards.md`](../standards/version-control-standards.md)
- [`../standards/docker-image-versioning.md`](../standards/docker-image-versioning.md) (§ Scanner Image Versioning)
- [`../standards/database-management.md`](../standards/database-management.md)
- [`../standards/api-endpoint-auth.md`](../standards/api-endpoint-auth.md)
- [`../standards/secure-coding.md`](../standards/secure-coding.md)
- [`../standards/kustomize-standards.md`](../standards/kustomize-standards.md)
- [`../standards/networkpolicy-templates.md`](../standards/networkpolicy-templates.md)

## Related documentation

- [`../scanners/`](../scanners/) — per-scanner deep-dive docs (integration guides, parsers, troubleshooting)
- [`../../TaskDocs-BlockSecOps/`](../../TaskDocs-BlockSecOps/) — full audit reports and RCAs for past scanner work
- `blocksecops-tool-integration/k8s/base/scanner-versions-configmap.yaml` — single source of truth for scanner image versions
