# API Service v0.27.5 - NetworkPolicy Rewrite & CronJob Secret Fix

## Version 0.27.5 - February 6, 2026

**Date:** 2026-02-06
**Component:** blocksecops-api-service
**Type:** Security / Bug Fix
**Priority:** High
**Status:** Complete

### Summary

Rewrote the api-service NetworkPolicy with correct namespace selectors, AND-based defense-in-depth targeting, and full service coverage for all 10 internal health-check dependencies. Fixed the deduplication CronJob secret name mismatch that caused `CreateContainerConfigError`.

### Issues Resolved

1. **NetworkPolicy namespace selectors never matched** - Used `name: postgresql-local` but namespaces have `kubernetes.io/metadata.name: postgresql-local`
2. **Ingress rule used wrong Traefik namespace** - `name: traefik` instead of `kubernetes.io/metadata.name: traefik-local`
3. **Egress `to:` arrays ORed instead of ANDed** - Separate items (namespace OR pod) instead of single object (namespace AND pod), defeating segmentation on enforcing CNIs
4. **Missing egress rules for 10 services** - API calls to orchestration, notification, data-service, vault, traefik, dashboard, admin-portal, intelligence, contract-parser, and harbor had no egress policies
5. **`egress-internet` too permissive** - `namespaceSelector: {}` allowed HTTPS to any namespace, defeating network segmentation
6. **DNS egress used wrong namespace selector** - `name: kube-system` instead of `kubernetes.io/metadata.name: kube-system`
7. **CronJob secret name mismatch** - `api-service-secrets` (plural) did not match ExternalSecret target `api-service-secret` (singular), causing `CreateContainerConfigError`

### Fixed

- **NetworkPolicy namespace selectors** - All policies now use `kubernetes.io/metadata.name: <ns>` which matches the auto-applied Kubernetes label
- **Egress AND selectors** - All egress rules use single `to:` objects with both `namespaceSelector` and `podSelector` for defense-in-depth (traffic must match both namespace AND pod label)
- **CronJob secret reference** - `api-service-secrets` changed to `api-service-secret` on line 71 of `cronjob-deduplication.yaml`

### Added

- **10 new per-service egress NetworkPolicies:**

| Policy Name | Namespace | Pod Label | Port |
|---|---|---|---|
| `api-service-to-orchestration` | `orchestration-local` | `app: orchestration` | 8004 |
| `api-service-to-notification` | `notification-local` | `app: notification` | 8003 |
| `api-service-to-data-service` | `data-service-local` | `app: data-service` | 8001 |
| `api-service-to-vault` | `vault-local` | `app.kubernetes.io/name: vault` | 8200 |
| `api-service-to-traefik` | `traefik-local` | `app.kubernetes.io/name: traefik` | 8080 |
| `api-service-to-dashboard` | `dashboard-local` | `app.kubernetes.io/name: dashboard` | 3000 |
| `api-service-to-admin-portal` | `admin-portal-local` | `app: admin-portal` | 3000 |
| `api-service-to-intelligence` | `intelligence-engine-local` | `app: intelligence-engine` | 80 |
| `api-service-to-contract-parser` | `contract-parser-local` | `app: contract-parser` | 80 |
| `api-service-to-harbor` | `harbor-local` | `app: harbor` | 80 |

### Changed

- **`api-service-egress-internet` replaced by `api-service-egress-external-apis`** - Now uses `ipBlock: 0.0.0.0/0` excluding RFC1918 (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) on port 443 only. No more `namespaceSelector: {}` loophole.
- **Total NetworkPolicies: 6 -> 17** (1 default-deny + 1 ingress + 15 egress)
- Version bump: `0.27.4` to `0.27.5` (PATCH - security fix)

### Removed

- `api-service-egress-internet` policy (replaced by `api-service-egress-external-apis`)

### Code Changes

**Files Modified:**
- `k8s/base/api-service/networkpolicy.yaml` - Complete rewrite (187 -> 428 lines)
- `k8s/base/api-service/cronjob-deduplication.yaml` (line 71) - Secret name fix
- `pyproject.toml` (line 7) - Version `0.27.4` -> `0.27.5`
- `k8s/overlays/local/api-service/kustomization.yaml` (line 30) - `newTag: "0.27.5"`

**Key Change - AND Selector Pattern (defense-in-depth):**
```yaml
# BEFORE (broken - OR logic, any pod in namespace OR any namespace with label):
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            name: postgresql-local       # Wrong label key
      - podSelector:                     # Separate item = OR
          matchLabels:
            app.kubernetes.io/name: postgresql

# AFTER (correct - AND logic, must match BOTH namespace AND pod):
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: postgresql-local  # Correct label
        podSelector:                                        # Same item = AND
          matchLabels:
            app.kubernetes.io/name: postgresql
```

**Key Change - External APIs (RFC1918 exclusion):**
```yaml
# BEFORE (overly permissive - any namespace on 443):
egress:
  - to:
      - namespaceSelector: {}
    ports:
      - protocol: TCP
        port: 443

# AFTER (restricted - external IPs only, no internal networks):
egress:
  - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except:
            - 10.0.0.0/8
            - 172.16.0.0/12
            - 192.168.0.0/16
    ports:
      - protocol: TCP
        port: 443
```

### Testing

**Verification Results:**
- `kubectl get networkpolicy -n api-service-local` - 17 policies
- `kubectl describe netpol api-service-to-vault -n api-service-local` - port 8200, vault-local, AND selector
- `kubectl describe netpol api-service-egress-external-apis -n api-service-local` - ipBlock excludes RFC1918
- `curl -sk https://app.0xapogee.local/api/v1/health/live` - `{"version":"0.27.5"}`
- Deduplication CronJob: no `CreateContainerConfigError`

### Impact

- **Security:** NetworkPolicies now correctly enforce on Calico/Cilium CNIs (previously all selectors silently failed to match)
- **CronJob:** Deduplication maintenance job can now start and access the database
- **Breaking Changes:** None - existing connectivity preserved; policies now actually enforce
- **CNI Note:** Current cluster runs Flannel (non-enforcing); fixes are production-ready for Calico/Cilium migration

### Related Documentation

- [Kubernetes Pod Lifecycle Standards](../standards/kubernetes-pod-lifecycle.md) - Updated NetworkPolicy patterns
- [Docker Image Versioning](../standards/docker-image-versioning.md) - Service versions table updated
- [Kubernetes Security Feature Test](../feature-tests/51-kubernetes-security.md) - Updated policy count
- [Admin Portal v0.3.1 Changelog](ADMIN-PORTAL-V0.3.1-HTTPS-INGRESSROUTE-2026-02-06.md) - Companion fix

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.27.5 | 2026-02-06 | NetworkPolicy rewrite, CronJob secret fix |
| 0.27.4 | 2026-02-06 | Scan timeout auto-retry |
| 0.27.2 | 2026-02-06 | Wallet auth nonce fix, OAuth plumbing |
| 0.27.0 | 2026-02-06 | Info severity removal, pending-to-queued mapping |

---

**Maintained By:** Apogee Team
**Status:** Complete
