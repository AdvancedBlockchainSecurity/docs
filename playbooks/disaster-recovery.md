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
| PostgreSQL (GCP) | In-cluster StatefulSet (GCE PD) | On-demand (GCS CronJob pending) | 30 days | GCS bucket |
| PostgreSQL (GCP) | PVC snapshot | On-demand | 7 days | Same region |
| PostgreSQL (local) | Manual `pg_dump` | On-demand | 7 days | `docs/database/backups/` |
| Vault secrets | `init-vault-local.sh` | On cluster init | N/A | Git (script only) |
| GCP secrets | Secret Manager versioning | Every change | All versions | GCP |
| Application code | Git | Every commit | Permanent | GitHub |
| Kubernetes manifests | Git (kustomize) | Every commit | Permanent | GitHub |
| Docker images | Harbor (local) / Artifact Registry (GCP) | Every build | Immutable tags | Registry |

### What Is NOT Backed Up

| Component | Recovery Method |
|-----------|----------------|
| Redis cache (local) | Ephemeral — rebuilt on restart, no data loss |
| Redis cache (GCP) | PVC-backed persistence with RDB snapshots |
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
curl -sk https://app.0xapogee.com/api/v1/health/ready
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

## Scenario 2: Database Corruption (GCP — In-Cluster PostgreSQL)

### From PVC Snapshot

```bash
# 1. Scale down PostgreSQL
kubectl scale statefulset/postgresql -n postgresql-prod --replicas=0

# 2. Create a VolumeSnapshot of the PVC (if VolumeSnapshot CRD installed)
cat <<EOF | kubectl apply -f -
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: postgresql-recovery-snapshot
  namespace: postgresql-prod
spec:
  source:
    persistentVolumeClaimName: postgresql-data-postgresql-0
EOF

# 3. Delete and recreate PVC from snapshot
kubectl delete pvc postgresql-data-postgresql-0 -n postgresql-prod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data-postgresql-0
  namespace: postgresql-prod
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: postgresql-recovery-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
EOF

# 4. Scale up PostgreSQL
kubectl scale statefulset/postgresql -n postgresql-prod --replicas=1

# 5. Restart services
for svc in api-service data-service intelligence-engine orchestration; do
  kubectl rollout restart deployment/$svc -n ${svc}-prod
done
```

### From GCS Backup (when CronJob backup is configured)

```bash
# 1. Download backup from GCS
gsutil cp gs://apogee-backups/postgresql/latest.sql.gz /tmp/

# 2. Copy to PostgreSQL pod
gunzip /tmp/latest.sql.gz
kubectl cp /tmp/latest.sql postgresql-prod/postgresql-0:/tmp/restore.sql

# 3. Restore
kubectl exec -n postgresql-prod postgresql-0 -- \
  pg_restore -U blocksecops -d solidity_security -c /tmp/restore.sql

# 4. Restart services
for svc in api-service data-service intelligence-engine orchestration; do
  kubectl rollout restart deployment/$svc -n ${svc}-prod
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
curl -sk https://app.0xapogee.com/api/v1/health/ready
```

---

## Scenario 4: GKE Cluster Loss

```bash
# 1. Recreate GKE cluster via Terraform
cd terraform/environments/gcp
terraform apply

# 2. Reconnect to cluster
gcloud container clusters get-credentials blocksecops-staging-gke \
  --region us-west1 --project project-8a2657b9-d96c-4c0a-a69

# 3. Deploy infrastructure (PostgreSQL, Redis, ESO, NetworkPolicies, Ingress)
kubectl apply -k ~/Git/blocksecops-gcp-infrastructure/k8s/overlays/gcp/

# 4. Recreate PostgreSQL credentials secret
kubectl create secret generic postgresql-credentials -n postgresql-prod \
  --from-literal=POSTGRES_DB=solidity_security \
  --from-literal=POSTGRES_USER=blocksecops \
  --from-literal=POSTGRES_PASSWORD=<secure-password>

# 5. Restore PostgreSQL data from GCS backup (if available)
# See Scenario 2 above

# 6. Deploy services from each service repo
for svc in data-service api-service orchestration intelligence-engine \
  notification tool-integration contract-parser dashboard admin-portal; do
  cd ~/Git/blocksecops-${svc}
  kubectl apply -k k8s/overlays/gcp/
done

# 7. Or re-enable Config Sync for automatic deployment
# See: docs/runbooks/DEPLOYMENT-RUNBOOK.md Phase 6

# 8. Verify all services
kubectl get pods --all-namespaces | grep -v Running
```

**Note:** PostgreSQL and Redis run in-cluster on GKE. A cluster loss means database data is also lost unless PVC snapshots or GCS backups exist. Ensure backup CronJob is configured.

---

## Scenario 5: Region Outage (GCP)

If `us-west1` becomes unavailable:

1. **Database:** Restore from GCS backup in new region (in-cluster PostgreSQL does not have cross-region replication)
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
