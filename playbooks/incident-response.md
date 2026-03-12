# Playbook: Incident Response

**Version:** 1.0.0
**Last Updated:** February 25, 2026
**Audience:** Platform Operator
**Priority:** Medium (within 30 days of launch)

## Overview

Procedures for detecting, responding to, and recovering from incidents affecting the Apogee platform.

---

## Severity Levels

| Level | Definition | Response Time | Examples |
|-------|-----------|---------------|---------|
| **SEV1** | Platform down, data loss, security breach | 15 min | All services unreachable, database corruption, credential leak |
| **SEV2** | Major feature degraded, payment failure | 30 min | Scan pipeline broken, Stripe webhooks failing, auth errors |
| **SEV3** | Minor feature degraded, performance issue | 4 hours | Slow queries, single service restart, non-critical endpoint errors |
| **SEV4** | Cosmetic, informational | Next business day | UI glitch, log noise, non-user-facing |

---

## Initial Response (All Severities)

### 1. Assess

```bash
# Quick cluster health
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# API health
curl -sk https://app.0xapogee.com/api/v1/health/ready

# Recent events
kubectl get events --all-namespaces --field-selector type=Warning \
  --sort-by='.lastTimestamp' | tail -20

# Recent errors
kubectl logs -n api-service-local deploy/api-service --since=10m | \
  grep -c "ERROR\|CRITICAL"
```

### 2. Classify

Determine severity based on:
- **User impact:** How many users affected? Can they work around it?
- **Data impact:** Is data at risk? Is data being lost?
- **Revenue impact:** Are payments failing? Is billing affected?
- **Security impact:** Is there unauthorized access?

### 3. Communicate

| Severity | Internal | External |
|----------|----------|----------|
| SEV1 | Immediate team notification | Status page update within 30 min |
| SEV2 | Team notification within 1 hour | Status page if > 1 hour |
| SEV3 | Daily standup mention | No external communication |
| SEV4 | Ticket created | None |

---

## Common Incident Playbooks

### Service Unreachable (SEV1/SEV2)

```bash
# 1. Check pod status
kubectl get pods -n ${SERVICE}-local

# 2. Check pod events
kubectl describe pod -n ${SERVICE}-local -l app=${SERVICE}

# 3. Check logs
kubectl logs -n ${SERVICE}-local deploy/${SERVICE} --tail=100

# 4. Common causes:
#    - OOMKilled → Increase memory limit
#    - CrashLoopBackOff → Check logs for startup error
#    - ImagePullBackOff → Verify image exists in registry
#    - Pending → Check node resources (kubectl top nodes)

# 5. Quick fix: restart
kubectl rollout restart deployment/${SERVICE} -n ${SERVICE}-local

# 6. If restart fails, rollback
kubectl rollout undo deployment/${SERVICE} -n ${SERVICE}-local
```

### Database Connection Failures (SEV1)

```bash
# 1. Check PostgreSQL pod
kubectl get pods -n postgresql-local
kubectl logs -n postgresql-local postgresql-0 --tail=50

# 2. Check connection count
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT count(*) FROM pg_stat_activity;"

# 3. Check for blocked queries
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT pid, age(clock_timestamp(), query_start), state, query
      FROM pg_stat_activity WHERE state != 'idle' ORDER BY query_start;"

# 4. Kill long-running queries if needed
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity
      WHERE state = 'active' AND query_start < now() - interval '5 minutes';"

# 5. Restart services to reset connection pools
kubectl rollout restart deployment/api-service -n api-service-local
```

### High Error Rate (SEV2/SEV3)

```bash
# 1. Identify error pattern
kubectl logs -n api-service-local deploy/api-service --since=30m | \
  grep "ERROR" | awk '{print $NF}' | sort | uniq -c | sort -rn | head -10

# 2. Check for specific HTTP error codes
kubectl logs -n api-service-local deploy/api-service --since=30m | \
  grep -oP '"status_code":\d+' | sort | uniq -c | sort -rn

# 3. Check resource pressure
kubectl top pods -n api-service-local

# 4. If resource constrained, scale up temporarily
kubectl scale deployment/api-service -n api-service-local --replicas=2
```

### ExternalSecret Sync Failure (SEV2)

```bash
# 1. Check status
kubectl get externalsecret --all-namespaces

# 2. Identify failing secret
kubectl describe externalsecret -n ${NS} ${NAME} | grep "error processing"

# 3. Check Vault
export VAULT_TOKEN=$(kubectl exec -n vault-local vault-0 -- \
  awk -F'"' '/root_token/{print $4}' /vault/data/.vault-init.json)
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv get ${VAULT_PATH}

# 4. If path missing, seed it
kubectl exec -n vault-local vault-0 -- \
  env VAULT_TOKEN="$VAULT_TOKEN" vault kv put ${VAULT_PATH} key="value"

# 5. If ESO stuck, force resync
kubectl delete externalsecret -n ${NS} ${NAME}
kubectl apply -k k8s/overlays/local/${SERVICE}/
```

### Stripe Webhook Failures (SEV2)

```bash
# 1. Check webhook endpoint is receiving events
kubectl logs -n api-service-local deploy/api-service --since=1h | \
  grep "stripe_webhook"

# 2. Check Stripe Dashboard → Developers → Webhooks
# Look for failed deliveries, error codes

# 3. Common causes:
#    - Webhook secret mismatch → Rotate webhook secret
#    - Endpoint unreachable → Check Traefik IngressRoute
#    - Signature verification failure → Check clock skew

# 4. Retry failed events in Stripe Dashboard
```

### Celery Worker Pod Kills (SEV3)

```bash
# 1. Check for liveness probe failures
kubectl get events -n api-service-local --field-selector reason=Unhealthy

# 2. Check worker resources
kubectl top pods -n api-service-local -l app=celery-worker

# 3. Check probe timing
kubectl get deployment celery-worker -n api-service-local \
  -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}' | python3 -m json.tool

# 4. If CPU starved, increase request (current: 250m)
# See: changelogs/API-SERVICE-V0.29.27-CLUSTER-WARNING-REMEDIATION-2026-02-24.md
```

### Disk Space Critical (SEV2)

```bash
# 1. Check disk usage
df -h /

# 2. Docker cleanup
docker image prune -a --force
docker builder prune -a --force

# 3. Check for large files
du -sh /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/* 2>/dev/null | \
  sort -rh | head -5

# 4. Clean old containerd snapshots
sudo crictl rmi --prune
```

---

## GCP Production Incident Response

### Initial Assessment (GCP)

```bash
# Quick cluster health
kubectl get pods --all-namespaces | grep -v Running | grep -v Completed

# API health (via external endpoint)
curl -s https://app.0xapogee.com/api/v1/health/ready

# Recent events
kubectl get events --all-namespaces --field-selector type=Warning \
  --sort-by='.lastTimestamp' | tail -20

# Check monitoring alerts
gcloud alpha monitoring policies list \
  --format='table(displayName,enabled)' \
  --filter="enabled=true"
```

### Service Unreachable (GCP — SEV1/SEV2)

```bash
# 1. Check pod status
kubectl get pods -n ${SERVICE}-prod

# 2. Check pod events
kubectl describe pod -n ${SERVICE}-prod -l app.kubernetes.io/name=${SERVICE}

# 3. Check logs
kubectl logs -n ${SERVICE}-prod deploy/${SERVICE} --tail=100

# 4. GCP-specific causes:
#    - ExternalSecret sync failure → Check ESO: kubectl get es -n ${SERVICE}-prod
#    - Workload Identity misconfigured → Check SA annotations
#    - Node pool scaling → Check: kubectl get nodes
#    - Cloud Armor blocking → Check WAF logs in Cloud Console

# 5. Quick fix: restart
kubectl rollout restart deployment/${SERVICE} -n ${SERVICE}-prod

# 6. If restart fails, rollback via Git (Config Sync auto-applies)
cd ~/Git/blocksecops-${SERVICE}
git revert HEAD && git push origin main
```

### Database Connection Failures (GCP — SEV1)

```bash
# 1. Check in-cluster PostgreSQL pod
kubectl get pods -n postgresql-prod
kubectl logs -n postgresql-prod postgresql-0 --tail=50

# 2. Verify pg_isready
kubectl exec -n postgresql-prod postgresql-0 -- pg_isready -U blocksecops -d solidity_security

# 3. Check connection count
kubectl exec -n postgresql-prod postgresql-0 -- \
  psql -U blocksecops -d solidity_security \
  -c "SELECT count(*) FROM pg_stat_activity;"

# 4. Restart services to reset connection pools
kubectl rollout restart deployment/api-service -n api-service-prod
```

### ExternalSecret Sync Failure (GCP — SEV2)

```bash
# 1. Check status
kubectl get externalsecret --all-namespaces

# 2. Identify failing secret
kubectl describe externalsecret -n ${NS} ${NAME}

# 3. Check GCP Secret Manager
gcloud secrets versions access latest --secret=apogee-gcp-${SECRET_NAME}

# 4. If secret missing, create it
echo -n "value" | gcloud secrets versions add apogee-gcp-${SECRET_NAME} --data-file=-

# 5. Force ESO resync
kubectl annotate externalsecret ${NAME} -n ${NS} \
  force-sync=$(date +%s) --overwrite
```

### etcd Encryption Issues (GCP — SEV2)

```bash
# 1. Verify encryption state
gcloud container clusters describe blocksecops-staging-gke \
  --region us-west1 --format='value(databaseEncryption.state)'
# Expected: ENCRYPTED

# 2. Check KMS key status
gcloud kms keys describe apogee-production-gke-etcd-key \
  --keyring=apogee-production-gke-etcd --location=us-west1 \
  --format='value(primary.state)'
# Expected: ENABLED

# 3. If key is disabled/destroyed, re-enable immediately
gcloud kms keys versions enable <VERSION_ID> \
  --key=apogee-production-gke-etcd-key \
  --keyring=apogee-production-gke-etcd --location=us-west1
```

### Monitoring Alert False Positives

```bash
# 1. Check alert policy details
gcloud alpha monitoring policies list --format='json' | \
  python3 -c "import sys,json; [print(p['displayName'], p['conditions'][0]['conditionThreshold']['thresholdValue']) for p in json.load(sys.stdin)]"

# 2. Silence an alert temporarily (create snooze)
# Use Cloud Console: Monitoring → Alerting → Snooze

# 3. Adjust threshold if needed
# Edit the alert policy in terraform/environments/gcp/main.tf
```

---

## Security Incident Response

### Suspected Credential Leak (SEV1)

1. **Immediately rotate** all potentially compromised secrets (see [Secret Rotation](secret-rotation.md))
2. **Check audit logs** for unauthorized access:
   ```bash
   kubectl exec -n postgresql-local postgresql-0 -- \
     psql -U blocksecops -d solidity_security \
     -c "SELECT * FROM audit_logs WHERE created_at > now() - interval '24 hours' ORDER BY created_at DESC LIMIT 50;"
   ```
3. **Review API access patterns** for anomalies
4. **Block suspicious IPs** via Traefik middleware if identified
5. **Document** findings for post-incident review

### Unauthorized API Access (SEV1)

1. **Identify the source** (IP, user, API key)
2. **Revoke access** (disable API key, deactivate user)
3. **Rotate affected secrets**
4. **Review data accessed** via audit logs
5. **Notify affected users** if data exposed

---

## Post-Incident Review

Within 48 hours of SEV1/SEV2 resolution:

### Template

```markdown
# Incident Report: [Brief Title]

**Date:** YYYY-MM-DD
**Duration:** HH:MM start → HH:MM resolved (X hours)
**Severity:** SEV1/SEV2
**Impact:** [Number of users affected, services degraded]

## Timeline
- HH:MM — Incident detected
- HH:MM — Response initiated
- HH:MM — Root cause identified
- HH:MM — Fix applied
- HH:MM — Verified resolved

## Root Cause
[What caused the incident]

## Resolution
[What was done to fix it]

## Action Items
- [ ] [Preventive measure 1]
- [ ] [Preventive measure 2]

## Lessons Learned
[What we learned and how to prevent recurrence]
```

---

## Related

- [Deployment Runbook](deployment-runbook.md)
- [Secret Rotation](secret-rotation.md)
- [Disaster Recovery](disaster-recovery.md)
- [Vault Secret Management](vault-secret-management.md)
