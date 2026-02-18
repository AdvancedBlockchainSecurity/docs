# Feature Test 69: Scanner Ecosystem Audit

**Date:** 2026-02-18
**Status:** Pass
**Services:** api-service (0.28.44), orchestration (0.9.14), tool-integration (0.4.7)

---

## Scope

Full audit and remediation of scanner ecosystem across orchestration, api-service, and tool-integration. Fixes ConfigMap drift, deprecated scanner registrations, missing parsers, and standards violations.

---

## Changes Tested

### ConfigMap Consistency
- Orchestration `scanner-images-configmap.yaml` rebuilt with correct env var names and pinned versions from source of truth
- Fixed: SOLAZY → SOL_AZY, SEC3 → SEC3X, CARGO_FUZZ → CARGO_AUDIT, SLITHER_VYPER → VYPER_SLITHER
- Added missing: RUSTDEFEND, VYPER_SEMGREP
- Removed deprecated: MYTHRIL, 4NALY3ER, FOUNDRY_FUZZ
- Removed all `:latest` tags — all 14 scanners now pinned
- API Service ConfigMap synced: SOLHINT 0.1.7 → 0.1.8, removed duplicate env vars

### Deprecated Scanner Removal
- Removed MythrilExecutor, FoundryFuzzExecutor, FournalyzerExecutor from orchestration registry
- MythrilParser marked as legacy-only in tool-integration (retained for historical scan parsing)

### New Parsers
- HalmosParser: Dedicated parser for Halmos formal verification output
- SolidityDefendParser: Dedicated parser for SolidityDefend SAST output
- Both registered in parser dispatch factory

### RustDefend v0.5.1 Upgrade
- Tool version: 0.3.0 → 0.5.1 (61 detectors, 347 fewer FPs)
- Image version: 0.3.1 → 0.4.2
- Repo URL migrated: `github.com/BlockSecOps/RustDefend` → `github.com/0xStarBridge/RustDefend`

---

## Test Results

| # | Test | Result | Details |
|---|------|--------|---------|
| 1 | Service health endpoints | Pass | All 3 services healthy, API v0.28.44 |
| 2 | Scanner metadata (GET /api/v1/scanners) | Pass | 16 scanners returned, 0 deprecated |
| 3 | ConfigMap consistency across services | Pass | All 14 orchestration scanner images match source of truth |
| 4 | Parser dispatch + OCI image labels | Pass | HalmosParser, SolidityDefendParser, MythrilParser (legacy) all registered |
| 5 | Orchestration registry | Pass | 16 scanners registered, 0 deprecated |
| 6 | Database records | Pass | 3,825 vulnerabilities, 460 scans, 5 RustDefend findings |
| 7 | RustDefend test scan (VulnerableStaking) | Pass | 4 critical findings (Integer Overflow), full Job lifecycle verified |
| 8 | All scanner github_urls | Pass | Only RustDefend changed to 0xStarBridge, no stale references |
| 9 | Running pod image version | Pass | api-service:0.28.44, 0 restarts |
| 10 | Codebase grep for old URL | Pass | Zero references to BlockSecOps/RustDefend in api-service, tool-integration, orchestration |
| 11 | New GitHub URL reachable | Pass | https://github.com/0xStarBridge/RustDefend returns HTTP 200 |
| 12 | UI path via Traefik | Pass | https://app.blocksecops.local/api/v1/scanners returns updated URL |

---

## Issues Found During Testing

1. **3 version mismatches** in orchestration ConfigMap (HALMOS, SOL_AZY, TRIDENT had stale values from remediation plan). Fixed immediately, committed, re-applied.
2. **socat missing on node** — port-forward from host to API pod fails. Workaround: test from within cluster pods.

---

## Verification Commands

```bash
# Health check
curl -sk https://app.blocksecops.local/api/v1/health/ready

# Scanner count and deprecated check
curl -sk https://app.blocksecops.local/api/v1/scanners | jq '.scanners | length'
curl -sk https://app.blocksecops.local/api/v1/scanners | jq '[.scanners[].id] | sort'

# RustDefend URL
curl -sk https://app.blocksecops.local/api/v1/scanners | jq '.scanners[] | select(.id=="rustdefend") | .github_url'

# ConfigMap verification
kubectl get configmap scanner-images -n orchestration-local -o yaml
kubectl get configmap scanner-versions -n api-service-local -o yaml
```
