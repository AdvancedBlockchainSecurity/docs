# Playbook: Disaster Recovery

**Version:** 1.0.0
**Last Updated:** February 25, 2026
**Audience:** Platform Operator
**Priority:** Low (within 90 days of launch)

## Overview

Procedures for recovering the Apogee platform from catastrophic failures including cluster loss, database corruption, and region-level outages.

---

## Recovery Targets

| Scenario | RTO (Recovery Time) | RPO (Data Loss) |
|----------|--------------------|-----------------|
| Single pod failure | < 2 min (auto-restart) | 0 |
| Single node failure | < 5 min (pod rescheduling) | 0 |
| Database corruption | < 30 min | < 15 min (PITR) |
| Full cluster rebuild | < 2 hours | < 24 hours (daily backup) |
| Region outage | < 4 hours (manual failover) | < 15 min (PITR) |

---

## Backup Inventory

### Automated Backups

| Component | Method | Frequency | Retention | Location |
|-----------|--------|-----------|-----------|----------|
| PostgreSQL (GCP) | Cloud SQL automated backup | Daily | 30 days | Same region |
| PostgreSQL (GCP) | Point-in-time recovery | Continuous (WAL) | 7 days | Same region |
| PostgreSQL (local) | Manual `pg_dump` | On-demand | 7 days | `docs/database/backups/` |
| Vault secrets | `init-vault-local.sh` | On cluster init | N/A | Git (script only) |
| GCP secrets | Secret Manager versioning | Every change | All versions | GCP |
| Application code | Git | Every commit | Permanent | GitHub |
| Kubernetes manifests | Git (kustomize) | Every commit | Permanent | GitHub |
| Docker images | Harbor (local) / Artifact Registry (GCP) | Every build | Immutable tags | Registry |

### What Is NOT Backed Up

| Component | Recovery Method |
|-----------|----------------|
| Redis cache | Ephemeral — rebuilt on restart, no data loss |
| Vault data (local) | Re-run `init-vault-local.sh` to reseed |
| User sessions | Users re-authenticate after recovery |
| Scan job state | Jobs retry from last checkpoint |

---

## Scenario 1: Database Corruption (Local)

### With Backup

```bash
# 1. Find latest backup
ls -lt docs/database/backups/

# 2. Stop services
kubectl scale deployment/api-service -n api-service-local --replicas=0

# 3. Restore backup
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U blocksecops -d postgres \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='solidity_security';"
kubectl exec -n postgresql-local postgresql-0 -- \
  dropdb -U blocksecops solidity_security
kubectl exec -n postgresql-local postgresql-0 -- \
  createdb -U blocksecops solidity_security

# Copy backup to pod and restore
kubectl cp backup_file.sql postgresql-local/postgresql-0:/tmp/restore.sql
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_restore -U blocksecops -d solidity_security /tmp/restore.sql

# 4. Restart services
kubectl scale deployment/api-service -n api-service-local --replicas=1
kubectl rollout status deployment/api-service -n api-service-local

# 5. Verify
curl -sk https://app.0xapogee.local/api/v1/health/ready
```

### Without Backup (Full Rebuild)

```bash
# 1. Delete and recreate PostgreSQL PVC
kubectl scale statefulset/postgresql -n postgresql-local --replicas=0
kubectl delete pvc -n postgresql-local -l app=postgresql
kubectl scale statefulset/postgresql -n postgresql-local --replicas=1

# 2. Wait for PostgreSQL to initialize
sleep 30

# 3. Create database
kubectl exec -n postgresql-local postgresql-0 -- \
  createdb -U blocksecops solidity_security

# 4. Run migrations
kubectl rollout restart deployment/api-service -n api-service-local
# (Alembic runs on startup)

# 5. Reseed test data if needed
# WARNING: All user data is lost
```

---

## Scenario 2: Database Corruption (GCP — Cloud SQL)

### Point-in-Time Recovery

```bash
# 1. Identify recovery point
gcloud sql instances describe blocksecops-db \
  --format="value(settings.backupConfiguration)"

# 2. Create recovery instance
gcloud sql instances clone blocksecops-db blocksecops-db-recovery \
  --point-in-time="2026-02-25T02:00:00Z"

# 3. Verify recovered data
gcloud sql connect blocksecops-db-recovery --user=blocksecops
# Run verification queries

# 4. Promote recovery instance (or update connection string)
# Option A: Update DATABASE_URL secret to point to recovery instance
# Option B: Export/import data back to original instance

# 5. Restart services
kubectl rollout restart deployment/api-service -n api-service
```

### From Daily Backup

```bash
# 1. List available backups
gcloud sql backups list --instance=blocksecops-db

# 2. Restore specific backup
gcloud sql backups restore BACKUP_ID --restore-instance=blocksecops-db

# 3. Wait for restore to complete
gcloud sql operations list --instance=blocksecops-db | head -5

# 4. Restart all services
for svc in api-service data-service intelligence-engine orchestration; do
  kubectl rollout restart deployment/$svc -n $svc
done
```

---

## Scenario 3: Full Cluster Rebuild (Local)

### Prerequisites

- Git repositories cloned (`~/Git/`)
- Docker installed
- `kubeadm` cluster initialized

### Steps

```bash
# 1. Initialize Kubernetes
sudo kubeadm init --pod-network-cidr=10.244.0.0/16

# 2. Apply Flannel CNI
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

# 3. Deploy infrastructure (order matters)
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/cert-manager/
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/traefik/
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/vault/
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/external-secrets/
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/postgresql/
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/local/redis/

# 4. Seed Vault secrets
./docs/scripts/init-vault-local.sh

# 5. Deploy Harbor
# (Follow Harbor installation docs)

# 6. Build and push all service images
for svc in api-service data-service intelligence-engine notification \
  orchestration tool-integration contract-parser dashboard admin-portal; do
  cd ~/Git/blocksecops-${svc}
  VERSION=$(grep -E '^version|"version"' pyproject.toml package.json 2>/dev/null | head -1 | grep -oP '[\d.]+')
  docker build -t harbor.blocksecops.local/blocksecops/${svc}:${VERSION} .
  docker push harbor.blocksecops.local/blocksecops/${svc}:${VERSION}
  kubectl apply -k k8s/overlays/local/${svc}/ 2>/dev/null || \
    kubectl apply -k k8s/overlays/local/ 2>/dev/null
done

# 7. Restore database from backup (if available)
# See Scenario 1 above

# 8. Verify
curl -sk https://app.0xapogee.local/api/v1/health/ready
```

---

## Scenario 4: GKE Cluster Loss

```bash
# 1. Recreate GKE cluster via Terraform
cd terraform/environments/production
terraform apply

# 2. ArgoCD will auto-deploy all applications
# Or manual: kubectl apply -k for each service

# 3. Restore database if needed (Cloud SQL is independent of GKE)
# Cloud SQL persists through GKE cluster loss

# 4. Verify all services
kubectl get pods --all-namespaces | grep -v Running
```

---

## Scenario 5: Region Outage (GCP)

If `us-west1` becomes unavailable:

1. **Database:** Cloud SQL cross-region replica (if configured) or restore from backup in new region
2. **GKE:** Create new cluster in alternate region via Terraform
3. **Secrets:** GCP Secret Manager is multi-regional by default
4. **DNS:** Update DNS to point to new region's load balancer
5. **Images:** Artifact Registry is multi-regional

**Note:** Cross-region failover is not currently automated. Manual intervention required.

---

## DR Testing Schedule

| Test | Frequency | Procedure |
|------|-----------|-----------|
| Backup restoration | Quarterly | Restore latest backup to test instance, verify data |
| Pod failure recovery | Monthly | `kubectl delete pod` random service, verify auto-recovery |
| Secret rotation | Quarterly | Rotate JWT secret, verify re-authentication works |
| Full cluster rebuild | Annually | Rebuild local cluster from scratch, time the process |

---

## Related

- [Database Management](../standards/database-management.md) — Backup procedures
- [Deployment Runbook](deployment-runbook.md) — Standard deployment
- [Secret Rotation](secret-rotation.md) — Secret management
- [Incident Response](incident-response.md) — Incident handling
