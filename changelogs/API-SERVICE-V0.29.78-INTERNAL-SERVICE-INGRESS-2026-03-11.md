# API Service v0.29.78 — Internal Service Ingress NetworkPolicy Fix

**Component:** blocksecops-api-service
**Scope:** NetworkPolicy, internal service-to-service communication
**Date:** March 11, 2026
**Status:** Deployed to GCP production
**PR:** [#313](https://github.com/AdvancedBlockchainSecurity/blocksecops-api-service/pull/313)

---

## Summary

The `api-service-ingress` NetworkPolicy only allowed ingress from `ingress-prod` and `kube-system`. Internal services (tool-integration, orchestration) that forward scan results and orchestrate scans via ClusterIP DNS were blocked by GKE Dataplane V2 (Cilium) default-deny enforcement.

---

## Changes

### NetworkPolicy Ingress Rules

**File:** `k8s/overlays/gcp/networkpolicy-ingress-patch.yaml`

Added two ingress rules using `namespaceSelector` + `podSelector` (AND logic) for defense-in-depth:

```yaml
# Allow from tool-integration (scan result forwarding via ClusterIP)
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: tool-integration-prod
    podSelector:
      matchLabels:
        app: tool-integration
  ports:
  - protocol: TCP
    port: 8000

# Allow from orchestration (scan orchestration via ClusterIP)
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: orchestration-prod
    podSelector:
      matchLabels:
        app: orchestration
  ports:
  - protocol: TCP
    port: 8000
```

### Version Bump

`0.29.77` -> `0.29.78` across `pyproject.toml` and all kustomization overlays (`gcp`, `local`, `production`).

---

## Verification

| Check | Result |
|-------|--------|
| tool-integration -> api-service:8000 | Reachable |
| orchestration -> api-service:8000 | Reachable |
| External ingress (ingress-prod) | Still allowed |
| Image deployed to GCP | Confirmed |

---

## Root Cause

When the platform migrated from local Flannel (where NetworkPolicies were documentation-only) to GKE Dataplane V2 (Cilium), NetworkPolicies became enforced at runtime. The `api-service-ingress` policy only listed external ingress sources, not internal services. On the local cluster this was invisible; on GCP it silently blocked scan result forwarding.

---

## Related

- tool-integration namespace audit fix: [blocksecops-tool-integration#136](https://github.com/AdvancedBlockchainSecurity/blocksecops-tool-integration/pull/136)
- GCP Secret Manager fix: `apogee-gcp-api-service-url` corrected to `api-service-prod`
