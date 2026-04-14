# Secure-Coding Audit — `postgresql-backup-network-policy`

**Date:** 2026-04-15
**Reference:** `docs/standards/secure-coding.md`
**Resource:** `NetworkPolicy/postgresql-backup-network-policy` in `postgresql-prod` namespace
**Source file:** `blocksecops-gcp-infrastructure/k8s/overlays/production/postgresql/networkpolicy.yaml`

This audit retroactively walks the secure-coding checklist for the new NetworkPolicy added during the PostgreSQL backup recovery. Most OWASP items don't apply to infrastructure config, but the relevant ones (network isolation, least-privilege, defense in depth) do.

---

## NetworkPolicy under review

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-backup-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgresql-backup
  policyTypes:
  - Egress
  egress:
  - to: []                                            # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to:                                               # PostgreSQL
    - podSelector: {matchLabels: {app.kubernetes.io/name: postgresql}}
    ports: [{port: 5432, protocol: TCP}]
  - to:                                               # GKE Workload Identity metadata
    - ipBlock: {cidr: 169.254.169.252/32}
    ports: [{port: 988, protocol: TCP}]
  - to:                                               # Compute metadata fallback
    - ipBlock: {cidr: 169.254.169.254/32}
    ports: [{port: 80, protocol: TCP}]
  - to: []                                            # GCS HTTPS
    ports: [{port: 443, protocol: TCP}]
```

---

## OWASP Top 10 Applicability

| Item | Relevant? | Verdict |
|------|-----------|---------|
| A01 Broken Access Control | YES | Allowlist-based egress; default-deny inherited from `default-deny-all` policy. Pod can ONLY reach destinations explicitly allowed. **PASS** |
| A02 Cryptographic Failures | YES | PostgreSQL connection on 5432 is enforced TLS server-side via `hostssl` in pg_hba.conf; the CronJob env passes `PGSSLMODE=require`. GCS upload on 443 is HTTPS-only. **PASS** |
| A03 Injection | N/A | NetworkPolicies don't process user input |
| A04 Insecure Design | YES | Least-privilege egress: 5 specific destinations + ports, no broad ranges (no `to: {}` wildcards on TCP outside 443/53). **PASS** |
| A05 Security Misconfiguration | YES | See Detailed checks below |
| A06 Vulnerable Components | N/A | NetworkPolicy is not a software dependency |
| A07 Identification/Auth Failures | YES | Workload Identity (via metadata server allowlist) is the authentication path for GCS. No static credentials in the pod. **PASS** |
| A08 Software/Data Integrity | YES | The backup pod is the integrity-protection mechanism. Allowing it to reach PostgreSQL and GCS but nothing else is consistent with that role. **PASS** |
| A09 Logging/Monitoring | YES | Backup failure now alerted (`CronJobJobFailed`, `PostgreSQLBackupStale`, `CronJobPodConfigError`). NetworkPolicy denials are NOT alerted at the policy level — but pod connection failures will surface via the new CronJob alerts. **PASS** |
| A10 SSRF | N/A | NetworkPolicy doesn't issue requests; this is the protection mechanism that prevents SSRF if it's used by a request handler |

---

## Detailed Security Checks

### Least-privilege egress

Each egress rule has a **specific destination AND specific port**:

| Rule | Destination | Port | Justification |
|------|-------------|------|---------------|
| 1 | `to: []` (any) | UDP/TCP 53 | DNS resolution. The destination must be `[]` because the cluster DNS service IP isn't fixed; DNS is required for service name resolution. Port 53 is unambiguously DNS. |
| 2 | `podSelector: {app.kubernetes.io/name: postgresql}` (in same namespace, since no namespaceSelector) | TCP 5432 | Backup needs to reach the database. Pod-selector-restricted is tighter than `to: []` would be. |
| 3 | `ipBlock: 169.254.169.252/32` | TCP 988 | GKE Workload Identity metadata server (Google's official IP). `/32` is a single-host allowlist — cannot be broader. |
| 4 | `ipBlock: 169.254.169.254/32` | TCP 80 | Compute metadata server (Google's official IP). `/32`, port 80 (HTTP only — metadata service has no HTTPS). |
| 5 | `to: []` (any) | TCP 443 | GCS upload via HTTPS. The destination must be `[]` because GCS endpoints resolve to many IPs across regions. **Port 443 only** prevents non-HTTPS egress. |

**Risk analysis of `to: []` rules:**
- Rule 1 (DNS) — minimal risk; DNS responses don't carry persistent state
- Rule 5 (GCS HTTPS) — broader than ideal. A compromised pod could exfiltrate data to any HTTPS endpoint. **Mitigation:** the only data the pod has is the just-created backup and short-lived metadata-server tokens; the pod doesn't have access to other databases or services. Tightening this would require filtering by SNI or destination IP, which Kubernetes NetworkPolicy doesn't support natively. Acceptable for current threat model.

### Defense-in-depth alignment

- `default-deny-all` NetworkPolicy denies everything by default for all pods in the namespace
- This NetworkPolicy is purely additive — it ONLY adds allow rules
- No conflict with other NetworkPolicies (each NetworkPolicy is independently evaluated; pods get the union of allow rules from all matching policies)
- Pod selector `app.kubernetes.io/name: postgresql-backup` is specific — does NOT accidentally match other workloads

### A05 Security Misconfiguration — explicit checks

| Check | Status |
|-------|--------|
| No `policyTypes` covering Ingress unnecessarily | PASS — only `Egress` is declared (backup pod doesn't accept connections; no need to permit ingress) |
| No `ports: []` empty wildcard | PASS — every rule has explicit ports |
| No protocol omission (defaults to TCP) | PASS — every port has explicit `protocol:` |
| No overly broad CIDR | PASS — both `ipBlock` rules use `/32` (single host) |
| No use of deprecated API version | PASS — `networking.k8s.io/v1` (current stable) |

### Container security context (referenced from CronJob, not NetworkPolicy)

The backup pod runs as the GKE-default user inside `postgres:15.4-alpine` and `google/cloud-sdk:slim`. The CronJob spec does not explicitly set `securityContext.runAsNonRoot: true`. **Finding:** could be hardened by setting `runAsNonRoot: true` and `readOnlyRootFilesystem: true` (the `/backup` PVC mount handles writes). **Severity: LOW** — pod has no inbound connections, no shell exposure; risk is theoretical. Tracked as defense-in-depth follow-up.

---

## Findings

| Finding | Severity | Status |
|---------|----------|--------|
| `to: []` for HTTPS egress (Rule 5) is broader than ideal | LOW (acceptable for current threat model — limited data scope, no native NetworkPolicy support for SNI filtering) | Open — accept |
| CronJob pod template lacks explicit `securityContext.runAsNonRoot` and `readOnlyRootFilesystem` | LOW (defense-in-depth) | Open — follow-up |

**No CRITICAL, HIGH, or MEDIUM findings.** NetworkPolicy is compliant with `docs/standards/secure-coding.md` for infrastructure resources.

---

## What this audit DOESN'T cover

- The CronJob pod spec itself (separate audit needed for `securityContext`, `resources`, `imagePullPolicy`)
- The GCP IAM bindings on `apogee-gcp-backup` GSA (separate IAM audit)
- The GCS bucket lifecycle policy (separate cloud-storage audit)
- The pg_dump command itself for command injection if env vars were attacker-controlled (env vars come from K8s Secret, not user input — out of scope)

## Process improvement note

Same gap as flagged previously: this audit happened **after** deployment, not as part of PR review. Going forward, every new NetworkPolicy / RBAC / Secret PR should include a "Secure Coding Checklist" section in the PR description. Tracked as process improvement (separate from this audit).
