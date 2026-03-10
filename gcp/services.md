# GCP Deployed Services

## Service Inventory

| Service | Namespace | Replicas | Image | Port |
|---------|-----------|----------|-------|------|
| api-service | api-service-prod | 1 | `apogee/api-service:0.29.75` | 8000 |
| celery-worker | api-service-prod | 1 | `apogee/api-service:0.29.75` | — |
| dashboard | dashboard-prod | 2 | `apogee/dashboard:0.46.23` | 3000 |
| admin-portal | admin-portal-prod | 1 | `apogee/admin-portal:0.7.11` | 3000 |
| data-service | data-service-prod | 1 | `apogee/data-service:0.2.7` | 8001 |
| intelligence-engine | intelligence-engine-prod | 1 | `apogee/intelligence-engine:0.3.7` | 80 |
| notification | notification-prod | 1 | `apogee/notification:0.2.6` | 8003 |
| orchestration | orchestration-prod | 1 | `apogee/orchestration:0.10.8` | 8004 |
| tool-integration | tool-integration-prod | 2 | `apogee/tool-integration:0.5.19` | 8005 |
| contract-parser | contract-parser-prod | 1 | `apogee/contract-parser:0.2.2` | 80 |

## Infrastructure Services

| Service | Namespace | Image |
|---------|-----------|-------|
| PostgreSQL | postgresql-prod | `pgvector/pgvector:pg15` |
| Redis | redis-prod | `redis:7.2-alpine` |
| External Secrets Operator | external-secrets-prod | `ghcr.io/external-secrets/external-secrets:v2.1.0` |
| cert-manager | cert-manager | `quay.io/jetstack/cert-manager-*` |

## Image Registry

All service images are in Artifact Registry:

```
us-west1-docker.pkg.dev/project-8a2657b9-d96c-4c0a-a69/apogee/<service>:<version>
```

GKE nodes pull images automatically via the node service account's IAM role (`artifactregistry.reader`). No `imagePullSecrets` needed.

## Dependency Order

Deploy infrastructure first, then services in dependency order:

```
1. cert-manager (TLS certificates)
2. PostgreSQL, Redis (data stores)
3. External Secrets Operator (secret sync)
4. data-service (database layer)
5. api-service + celery-worker (HTTP gateway + background tasks)
6. intelligence-engine, orchestration, tool-integration (backend)
7. notification (real-time)
8. contract-parser (analysis)
9. dashboard, admin-portal (frontend)
```

## External Dependencies

| Dependency | Used By | Secret |
|------------|---------|--------|
| Stripe | api-service | `apogee-gcp-stripe-api-key`, `apogee-gcp-stripe-webhook-secret` |
| Anthropic API | intelligence-engine | `apogee-gcp-anthropic-api-key` |
| OpenAI API | intelligence-engine | `apogee-gcp-openai-api-key` |
| Supabase | dashboard, admin-portal | `apogee-gcp-supabase-url`, `apogee-gcp-supabase-key` |
| SMTP | notification | `apogee-gcp-smtp-host`, `apogee-gcp-smtp-password` |

## Namespace Convention

All production namespaces use the `-prod` suffix:

```
api-service-prod         dashboard-prod           notification-prod
admin-portal-prod        data-service-prod        orchestration-prod
contract-parser-prod     external-secrets-prod    postgresql-prod
cert-manager             ingress-prod             redis-prod
intelligence-engine-prod tool-integration-prod
```

## Health Checks

```bash
# External (via load balancer)
curl -I https://app.0xapogee.com/api/v1/health/live

# Internal (via kubectl)
kubectl exec -n api-service-prod deploy/api-service -- curl -s http://localhost:8000/health

# All services (port-forward)
kubectl port-forward -n api-service-prod svc/api-service 8080:8000 &
curl http://localhost:8080/api/v1/health/ready
```
