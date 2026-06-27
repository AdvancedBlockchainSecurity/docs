# Security Audit — GKE Connect Gateway (ADV-28)

- **Date:** 2026-06-26
- **Scope:** `blocksecops-gcp-infrastructure` branch `feat/connect-gateway-access` — 6 changed files (terraform + runbook) adding GKE Fleet membership + Connect Gateway for roaming kubectl access.
- **Linear:** ADV-28
- **Result:** PASS (no FAIL, no blocking WARN). No new BSO-SEC finding minted.

## Changed surface

| File | Change |
|---|---|
| `terraform/environments/gcp/main.tf` | Enable `gkehub`, `connectgateway`, `anthos` APIs |
| `terraform/environments/gcp/connect-gateway.tf` (new) | `google_gke_hub_membership.primary` + `roles/gkehub.gatewayEditor` + `roles/gkehub.viewer` for `connect_gateway_users` |
| `terraform/environments/gcp/variables.tf` | New `connect_gateway_users` var with member-prefix validation |
| `terraform/environments/gcp/terraform.tfvars` | `connect_gateway_users = ["user:dehvcurtis@protonmail.com"]`; `admin_cidr_blocks` reconciled to live `136.36.116.105/32` |
| `terraform/environments/gcp/outputs.tf` | `connect_gateway_get_credentials_command` output |
| `docs/gcp/connect-gateway.md` (new) | Change summary + test/apply/verify/rollback runbook |

## Findings by dimension

1. **Secrets** — PASS. No API keys, tokens, passwords, or private keys in the diff hunks. Changed lines contain only non-secret config: control-plane allowlist IPs (`136.36.116.105/32`), the GCP project ID, and one operator email. `.env`, `.env.local`, `.env.*.local` are gitignored (repo `.gitignore:38-40`); no `.env` staged.
2. **Input validation** — PASS (improved). The new `connect_gateway_users` variable validates each member against `^(user|group|serviceAccount):` and rejects malformed entries at plan time.
3. **Auth boundaries** — PASS with note. The IAM grant is `roles/gkehub.gatewayEditor` (read/write kubectl through the gateway) + `roles/gkehub.viewer` (required to resolve the membership during `get-credentials`), scoped to the explicit `connect_gateway_users` list (currently one operator). In-cluster authorization remains governed by Kubernetes RBAC; the Google identity maps to RBAC, so the grant does not bypass cluster authz. NOTE: `gatewayEditor` (read/write) is deliberate — the operator runs `kubectl apply` for deploys. `roles/gkehub.gatewayReader` is the read-only alternative documented in the runbook for view-only operators.
4. **XSS / injection** — N/A (pure IaC, no user-facing input, no templated SQL/shell).
5. **Supply chain** — PASS. No new package dependencies. Uses the already-present `google-beta` provider. The three enabled APIs are Google first-party.
6. **External URLs** — PASS. Only `//container.googleapis.com/...` (the cluster resource link) — an intentional Google endpoint.
7. **Consent gates** — N/A.
8. **Inter-service auth** — N/A.
9. **Dynamic registry anti-pattern** — N/A (no hardcoded scanner/model/provider lists).

## Exposure delta

Net **reduction** in attack surface vs the alternative of per-location IP allowlisting: the change is additive and does not modify `master_authorized_networks` (shipped via targeted apply). Roaming access is gated behind Google IAM + Kubernetes RBAC rather than a widening list of allowlisted public IPs.

## Out of scope (pre-existing drift, not introduced here)

- `secret.rotatable[*].next_rotation_time` hardcoded to a past date (`2026-06-01`) — would force secret rotation on a full apply. Must be reconciled before any non-targeted `terraform apply`.
- Cluster auto-upgraded 1.34 → 1.35; state stale.

Both are tracked for a separate drift-cleanup ticket.
