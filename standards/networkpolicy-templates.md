# NetworkPolicy Templates Per Workload Type

**Status:** Active
**Last Updated:** 2026-04-15

## Why this exists

Every workload in a deny-all namespace must ship with its own NetworkPolicy. Forgetting one is silent — the workload appears to deploy, then fails on first network call (database reachability, Workload Identity metadata server, GCS, etc.). The `postgresql-backup` outage on 2026-04-13 to 2026-04-15 was caused in part by a missing NetworkPolicy egress rule (see `audit/2026-04-15-postgresql-backup-recovery-summary.md`).

This doc gives copy-pasteable starting points, organized by workload archetype. Always tailor before deploying.

## Default-deny baseline

Every namespace assumes a `default-deny-all` NetworkPolicy is already in place:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
```

Per-workload policies are **purely additive** — they only add allow rules.

---

## Archetype 1 — Internal HTTP service (typical microservice)

Pod accepts ingress from sibling services + ingress controller; egress to PostgreSQL/Redis + DNS + (optionally) other internal services.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <service>-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <service>
  policyTypes: [Ingress, Egress]
  ingress:
  # Sibling services (e.g., other microservices in <service>-prod)
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: <caller-namespace>-prod
    ports: [{port: 8000, protocol: TCP}]
  # Ingress controller (Gateway API or Traefik)
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-prod
    ports: [{port: 8000, protocol: TCP}]
  egress:
  - to: []                                           # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to:                                              # PostgreSQL
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: postgresql-prod}}
      podSelector: {matchLabels: {app.kubernetes.io/name: postgresql}}
    ports: [{port: 5432, protocol: TCP}]
  - to:                                              # Redis
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: redis-prod}}
      podSelector: {matchLabels: {app.kubernetes.io/name: redis}}
    ports: [{port: 6379, protocol: TCP}]
```

---

## Archetype 2 — CronJob with GCP egress (the postgresql-backup pattern)

Backup or maintenance Job that needs PostgreSQL + GKE Workload Identity metadata + GCS HTTPS.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: <cronjob>-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <cronjob>
  policyTypes: [Egress]                  # CronJobs don't accept ingress
  egress:
  - to: []                                            # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to:                                               # PostgreSQL (or other backend)
    - podSelector: {matchLabels: {app.kubernetes.io/name: postgresql}}
    ports: [{port: 5432, protocol: TCP}]
  - to:                                               # GKE Workload Identity metadata
    - ipBlock: {cidr: 169.254.169.252/32}
    ports: [{port: 988, protocol: TCP}]
  - to:                                               # Compute metadata fallback
    - ipBlock: {cidr: 169.254.169.254/32}
    ports: [{port: 80, protocol: TCP}]
  - to: []                                            # GCS HTTPS (broad — see note)
    ports: [{port: 443, protocol: TCP}]
```

> **Note on `to: []` for GCS:** GCS endpoints resolve to many regional IPs; we can't pin to a CIDR. The risk is mitigated by `ports: [443]` (HTTPS only) and the pod's tiny data scope (just the freshly-created backup). NetworkPolicy doesn't support SNI filtering natively. Live audit: `audit/2026-04-15-postgresql-backup-network-policy-security-review.md`.

---

## Archetype 3 — Scanner Job (NetworkPolicy "scanner-network-policy")

Tool-integration creates ephemeral scanner Jobs. Pods need DNS + a callback to tool-integration:8005, **nothing else**. Vendored dependencies make `crates.io` / `pypi` egress unnecessary.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: scanner-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/component: scanner
  policyTypes: [Egress]
  egress:
  - to: []                                            # DNS
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
  - to:                                               # tool-integration callback only
    - podSelector: {matchLabels: {app.kubernetes.io/name: tool-integration}}
    ports: [{port: 8005, protocol: TCP}]
```

Add the GKE metadata IPs (`169.254.169.252/32:988` + `169.254.169.254/32:80`) only if the scanner needs Workload Identity for cloud APIs.

---

## Archetype 4 — Stateful database (PostgreSQL, Redis)

Accept ingress from configured services; allow egress only for replication / health checks (none in our single-instance case).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgresql-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: postgresql
  policyTypes: [Ingress, Egress]
  ingress:
  - from:
    # Allow each consuming service explicitly (better than wildcard)
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: api-service-prod}}
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: data-service-prod}}
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: orchestration-prod}}
    - namespaceSelector: {matchLabels: {kubernetes.io/metadata.name: notification-prod}}
    # Backup pod (same namespace)
    - podSelector: {matchLabels: {app.kubernetes.io/name: postgresql-backup}}
    ports: [{port: 5432, protocol: TCP}]
  egress:
  - to: []                                            # DNS only
    ports: [{port: 53, protocol: UDP}, {port: 53, protocol: TCP}]
```

---

## Checklist — before you ship a new workload

- [ ] Workload has a NetworkPolicy in the same overlay folder as its Deployment / CronJob / StatefulSet
- [ ] `podSelector` matches the workload's pod labels exactly (no accidental wildcards)
- [ ] `policyTypes` is the minimum needed (`[Egress]` for outbound-only workers, `[Ingress, Egress]` for services)
- [ ] DNS egress is explicit (`port: 53` UDP + TCP)
- [ ] Every external destination has a port (no `ports: []`)
- [ ] CIDR allowlists use `/32` where the destination is a single host (metadata server, etc.)
- [ ] Pre-deploy diff: `kubectl apply -k --dry-run=server <overlay>` returns no errors
- [ ] Post-deploy smoke: pod reaches every destination it needs (`kubectl exec` + curl/nc); no NetworkPolicy denial in the new alerts (see `playbooks/postgresql-backup-operations.md` for the alert names)

## Anti-patterns

| Pattern | Why it's bad | Fix |
|---------|-------------|-----|
| `to: []` on TCP ports other than 443 / 53 | Allows egress to any IP on that port — kills the point of the policy | Restrict by `podSelector` / `namespaceSelector` / `ipBlock` |
| `ports: []` (empty) | Allows all ports — same problem | List specific ports |
| Omitting `protocol:` | Defaults to TCP; UDP rules silently dropped | Always set `protocol: TCP` or `protocol: UDP` |
| `policyTypes: [Ingress, Egress]` on a CronJob that has no ingress | Wastes admission cycles + clutters audits | `policyTypes: [Egress]` only |
| Sharing one NetworkPolicy across multiple workloads via broad `podSelector` | Hard to reason about; one workload change breaks others | One NetworkPolicy per workload |

## See also

- `audit/2026-04-15-postgresql-backup-network-policy-security-review.md` — full OWASP walkthrough of an example backup NetworkPolicy
- `playbooks/postgresql-backup-operations.md` — what to do when a NetworkPolicy denial breaks a workload
- `standards/secure-coding.md` — broader secure-coding checklist (NetworkPolicy is one of many controls)
