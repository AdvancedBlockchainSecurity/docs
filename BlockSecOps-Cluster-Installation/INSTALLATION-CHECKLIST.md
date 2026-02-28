# Apogee Installation Checklist

**Date Started:** _______________
**Completed By:** _______________

Use this checklist to track installation progress. Check off each item as completed.

---

## Phase 1: Minikube Setup

- [ ] Docker Desktop running with 12GB+ memory allocated
- [ ] Minikube started with `--cpus=8 --memory=11500`
- [ ] `minikube status` shows Running
- [ ] `kubectl cluster-info` shows cluster running
- [ ] Storage provisioner addon enabled

**Notes:**
```
Minikube version: _______________
Kubernetes version: _______________
```

---

## Phase 2: Platform Infrastructure

- [ ] Metrics Server deployed
- [ ] Metrics Server pod ready in kube-system
- [ ] `kubectl top nodes` returns data

---

## Phase 3: Database Services

### PostgreSQL
- [ ] PostgreSQL deployed to postgresql-local namespace
- [ ] PostgreSQL pod ready
- [ ] PVC created and bound
- [ ] Connection test successful (psql)

### Redis
- [ ] Redis deployed to redis-local namespace
- [ ] Redis pod ready
- [ ] Connection test successful (redis-cli ping)

---

## Phase 4: Security Infrastructure

### Vault
- [ ] Vault deployed to vault-local namespace
- [ ] Vault pod ready
- [ ] Vault unsealed (status shows sealed=false)
- [ ] Vault initialization script run
- [ ] All secrets verified in Vault

### External Secrets Operator
- [ ] CRDs installed
- [ ] External Secrets Operator deployed
- [ ] Operator pod ready

### Cert-Manager
- [ ] CRDs installed
- [ ] Cert-Manager deployed
- [ ] All cert-manager pods ready

---

## Phase 5: Networking & Ingress

### Traefik
- [ ] Traefik deployed to traefik-local namespace
- [ ] Traefik pod ready
- [ ] Traefik service created

### Network Policies
- [ ] Network policies applied
- [ ] Policies verified in all namespaces

---

## Phase 6: Container Registry

### Harbor
- [ ] Harbor deployed to harbor-local namespace
- [ ] All Harbor pods ready (core, jobservice, registry, etc.)
- [ ] Harbor proxy container started
- [ ] `curl -k https://localhost:5443/v2/` returns response
- [ ] Can login with `docker login`

---

## Phase 7: Monitoring Stack

- [ ] kube-prometheus-stack Helm release installed
- [ ] Prometheus pod ready
- [ ] Grafana pod ready
- [ ] Alertmanager pod ready
- [ ] Grafana accessible at http://127.0.0.1:3001

---

## Phase 8: Application Services

### Build Images
- [ ] API Service image built
- [ ] Dashboard image built
- [ ] Orchestration image built
- [ ] Tool Integration image built
- [ ] Intelligence Engine image built
- [ ] Data Service image built
- [ ] Notification image built

### Deploy Services

| Service | Deployed | Pod Ready | Endpoints OK |
|---------|----------|-----------|--------------|
| API Service | [ ] | [ ] | [ ] |
| Dashboard | [ ] | [ ] | [ ] |
| Orchestration | [ ] | [ ] | [ ] |
| Tool Integration | [ ] | [ ] | [ ] |
| Intelligence Engine | [ ] | [ ] | [ ] |
| Data Service | [ ] | [ ] | [ ] |
| Notification | [ ] | [ ] | [ ] |

### Database Setup
- [ ] Alembic migrations run
- [ ] Database schema verified
- [ ] Test user created (if applicable)

---

## Phase 9: Scanner Integration

### Scanner Images Built

| Scanner | Built | Version |
|---------|-------|---------|
| Slither | [ ] | _______ |
| Aderyn | [ ] | _______ |
| Wake | [ ] | _______ |
| Mythril | [ ] | _______ |
| Semgrep | [ ] | _______ |
| Solhint | [ ] | _______ |
| Echidna | [ ] | _______ |
| Medusa | [ ] | _______ |
| Halmos | [ ] | _______ |

---

## Phase 10: Verification & Testing

### Port Forwards Active
- [ ] Traefik (3000)
- [ ] Grafana (3001)
- [ ] Notification (8003)
- [ ] Harbor (8443)

### Health Checks
- [ ] `/api/v1/health/live` returns 200
- [ ] `/api/v1/health/ready` returns 200
- [ ] Dashboard loads at http://127.0.0.1:3000
- [ ] API docs load at http://127.0.0.1:3000/api/v1/docs

### External Secrets Sync
- [ ] All ExternalSecrets show "SecretSynced"
- [ ] All ExternalSecrets show "Ready: True"

### End-to-End Test
- [ ] Can create user account
- [ ] Can upload contract
- [ ] Can trigger scan
- [ ] Scan completes successfully
- [ ] Results displayed in dashboard

---

## Installation Complete

**Date Completed:** _______________

**Total Time:** _______________

**Issues Encountered:**
```


```

**Resolutions Applied:**
```


```

---

## Post-Installation Tasks

- [ ] Create cron job for automated backups
- [ ] Configure automated Vault re-initialization after restart
- [ ] Set up development workflow scripts
- [ ] Test scanner integration end-to-end
- [ ] Verify all documentation is accurate

---

## Quick Restart Procedure

After `minikube stop` and `minikube start`:

1. [ ] Wait for all pods to start: `kubectl get pods -A -w`
2. [ ] Re-initialize Vault secrets: `/Users/pwner/Git/ABS/scripts/init-vault-local.sh`
3. [ ] Start port forwards: `/Users/pwner/Git/ABS/scripts/start-port-forwards.sh`
4. [ ] Verify health: `curl http://127.0.0.1:3000/api/v1/health/ready`

---

**Checklist Version:** 1.0.0
**Last Updated:** December 13, 2025
