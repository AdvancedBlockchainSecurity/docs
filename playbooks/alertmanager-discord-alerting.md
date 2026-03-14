# Playbook: GKE Alertmanager Discord Alerting

**Version:** 1.0.0
**Last Updated:** March 14, 2026
**Audience:** Platform Engineer | SRE

## Overview

Infrastructure alerting for the Apogee platform using GKE Managed Prometheus Alertmanager routed to Discord via the alertmanager-discord bridge. This is distinct from user-facing notifications (see [chatops-discord.md](chatops-discord.md)) — this covers infrastructure and service health alerts.

---

## Architecture

```
ClusterRules (alerting-rules.yaml)
       |
       v
GKE Managed Prometheus Rule Evaluator
       |
       v
Alertmanager (gmp-system, managed by GKE)
       |  webhook_configs
       v
alertmanager-discord bridge (gmp-system, Deployment)
       |  Discord API
       v
Discord Channel
```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| ClusterRules | `apogee-platform-alerts` (cluster-scoped) | Defines alert conditions |
| Alertmanager config | Secret `alertmanager` in `gmp-public` | Routes, receivers, grouping |
| Discord bridge | Deployment `alertmanager-discord` in `gmp-system` | Translates Alertmanager payload to Discord format |
| Webhook URL | GCP Secret Manager `apogee-gcp-discord-webhook-url` → ESO → K8s Secret | Discord webhook credential |

### Why a bridge?

GKE Managed Prometheus Alertmanager supports `slack_configs` and `webhook_configs` natively. Discord's `/slack` compatible endpoint does not support Alertmanager's attachment format (returns 400). The [alertmanager-discord](https://github.com/benjojo/alertmanager-discord) bridge accepts standard `webhook_configs` payloads and posts them as Discord embeds.

---

## Alert Rules

| Group | Alert | Severity | For | Description |
|-------|-------|----------|-----|-------------|
| service-availability | PodNotReady | critical | 5m | Pod not ready for > 5 minutes |
| service-availability | PodCrashLooping | critical | 5m | Pod restarting repeatedly |
| service-availability | DeploymentReplicasMismatch | warning | 10m | Fewer ready replicas than desired |
| resource-utilization | ContainerCPUThrottling | warning | 15m | CPU throttling > 25% |
| resource-utilization | ContainerMemoryNearLimit | warning | 10m | Memory > 90% of limit |
| resource-utilization | PersistentVolumeNearFull | warning | 10m | PVC usage > 85% |
| database | PostgreSQLDown | critical | 2m | PostgreSQL StatefulSet has 0 replicas |
| database | RedisDown | critical | 2m | Redis StatefulSet has 0 replicas |
| certificates | CertificateExpiringSoon | warning | 1h | Certificate expires < 14 days |

### Alert Routing

| Severity | Receiver | Repeat Interval |
|----------|----------|-----------------|
| critical | discord-critical | 1 hour |
| warning | discord | 4 hours |

Alerts are grouped by `alertname`, `namespace`, `severity` with a 30s group wait and 5m group interval.

---

## GKE Managed Prometheus Config Model

GKE owns the `alertmanager` Secret in `gmp-system` and continuously reconciles it. You cannot edit it directly. The correct flow:

1. Create/edit the `alertmanager` Secret in **`gmp-public`** namespace
2. The GKE operator copies it to `gmp-system` automatically
3. Alertmanager config-reloader detects the change and reloads

The `OperatorConfig` CRD in `gmp-public` specifies which Secret and key to use:
```yaml
managedAlertmanager:
  configSecret:
    name: alertmanager
    key: alertmanager.yaml
```

This is pre-configured by GKE — no need to create it.

---

## Common Operations

### Update Discord Webhook URL

```bash
# Update in GCP Secret Manager
echo -n "https://discord.com/api/webhooks/NEW_ID/NEW_TOKEN" | \
  gcloud secrets versions add apogee-gcp-discord-webhook-url --data-file=-

# Force ESO re-sync
kubectl annotate externalsecret alertmanager-discord-webhook -n gmp-system \
  force-sync="$(date +%s)" --overwrite

# Restart bridge to pick up new secret
kubectl rollout restart deployment alertmanager-discord -n gmp-system
```

### Add a New Alert Rule

Edit `blocksecops-gcp-infrastructure/k8s/gcp/alerting/alerting-rules.yaml`, add a new rule under the appropriate group, then:

```bash
kubectl apply -k k8s/gcp/alerting/
```

### Update Alertmanager Config (routing, receivers)

Edit `blocksecops-gcp-infrastructure/k8s/gcp/alerting/alertmanager-config.yaml`, then:

```bash
kubectl apply -k k8s/gcp/alerting/
kubectl rollout restart statefulset alertmanager -n gmp-system
```

### Send a Test Alert

```bash
kubectl run alert-test -n gmp-system --restart=Never --image=curlimages/curl:latest --command -- \
  curl -s -X POST \
  "http://alertmanager-0.alertmanager.gmp-system.svc.cluster.local:9093/api/v2/alerts" \
  -H "Content-Type: application/json" \
  -d '[{"labels":{"alertname":"ManualTest","severity":"warning","namespace":"test"},"annotations":{"summary":"Manual test alert","description":"Testing alerting pipeline."}}]'

# Wait 30-40 seconds (group_wait), then check Discord
sleep 40
kubectl delete pod alert-test -n gmp-system
```

### Silence an Alert

```bash
# Port-forward to Alertmanager UI
kubectl port-forward -n gmp-system alertmanager-0 9093:9093
# Open http://localhost:9093 to create silences via UI
```

---

## Troubleshooting

### No alerts in Discord

1. Check bridge pod is running: `kubectl get pods -n gmp-system -l app=alertmanager-discord`
2. Check bridge logs: `kubectl logs -n gmp-system -l app=alertmanager-discord`
3. Check alertmanager errors: `kubectl logs -n gmp-system alertmanager-0 -c alertmanager | grep error`
4. Verify config synced: `kubectl get secret alertmanager -n gmp-system -o jsonpath='{.data.config\.yaml}' | base64 -d`
5. Verify webhook URL: `kubectl get secret alertmanager-discord-webhook -n gmp-system -o jsonpath='{.data.DISCORD_WEBHOOK_URL}' | base64 -d`

### Alertmanager config keeps reverting to noop

You edited the Secret in `gmp-system` instead of `gmp-public`. The GKE operator continuously reconciles `gmp-system`. Always edit in `gmp-public`.

### Alert fires but Discord returns error

Check the bridge logs for HTTP status codes. Common issues:
- 401: Webhook URL invalid or deleted — recreate in Discord and update GCP SM
- 429: Rate limited — reduce alert frequency or increase repeat_interval

---

## Codebase

| File | Purpose |
|------|---------|
| `blocksecops-gcp-infrastructure/k8s/gcp/alerting/alerting-rules.yaml` | ClusterRules CRD |
| `blocksecops-gcp-infrastructure/k8s/gcp/alerting/alertmanager-config.yaml` | Alertmanager config Secret (gmp-public) |
| `blocksecops-gcp-infrastructure/k8s/gcp/alerting/discord-bridge.yaml` | Bridge Deployment + Service + ExternalSecret |
| `blocksecops-gcp-infrastructure/k8s/gcp/alerting/kustomization.yaml` | Kustomization |

## GCP Secret Manager Keys

| Key | Purpose |
|-----|---------|
| `apogee-gcp-discord-webhook-url` | Discord webhook URL (no `/slack` suffix) |

---

## Related

- [Discord ChatOps (user-facing)](chatops-discord.md) — User-facing scan notifications
- [Incident Response](incident-response.md) — Responding to alerts
- [Disaster Recovery](disaster-recovery.md) — Recovery procedures
- [Platform Audit Checklist](../audit/PLATFORM-AUDIT-CHECKLIST.md) — ADV-2 resolution
