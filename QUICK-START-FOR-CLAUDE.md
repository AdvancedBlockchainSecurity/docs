# Quick Start Guide for Claude Code

**Purpose**: Fast reference for starting new development tasks

## 🚀 Before Starting ANY Task

1. **Read the Spec Kit**: `/Users/pwner/Git/ABS/docs/CLAUDE-SPEC-KIT.md`
2. **Check Sprint Tasks**: `/Users/pwner/Git/ABS/docs/Sprints/Sprint-1/Task-*.md`
3. **Review Current State**: See section below

---

## 📍 Current State (Updated: October 6, 2025)

### ✅ What's Done
- Infrastructure: minikube cluster running
- Services deployed: PostgreSQL, Redis, Vault, Monitoring, Harbor
- K8s templates: All 7 backend services (Task 1.10a ✅)
- Dashboard: React UI with mock data running on http://localhost:3000
- Shared library: Rust/Python/TypeScript types and utilities

### 🔨 What's Next
**Priority: Build API Service Backend**
- Create FastAPI application
- Implement authentication
- Connect to PostgreSQL
- Build Docker image
- Deploy to minikube
- Connect to dashboard

---

## 📂 Repository Locations

### Management & Planning
- **Sprint Tasks**: `/Users/pwner/Git/ABS/docs/Sprints/`
- **Architecture Decisions**: `/Users/pwner/Git/ABS/docs/architecture/`
- **Templates**: `/Users/pwner/Git/ABS/docs/architecture-templates/`

### Technical Documentation
- **Dev Guides**: `/Users/pwner/Git/ABS/solidity-security-docs/development/`
- **Architecture Specs**: `/Users/pwner/Git/ABS/solidity-security-docs/architecture/`
- **Local Dev**: `/Users/pwner/Git/ABS/solidity-security-docs/local-development/`

### Code Repositories
```
/Users/pwner/Git/ABS/
├── solidity-security-api-service/          # FastAPI gateway
├── solidity-security-data-service/         # Database operations
├── solidity-security-intelligence-engine/  # ML & risk scoring
├── solidity-security-orchestration/        # Celery workflows
├── solidity-security-tool-integration/     # Security tool adapters
├── solidity-security-notification/         # WebSocket notifications
├── solidity-security-contract-parser/      # Rust parser
├── solidity-security-dashboard/            # React UI
├── solidity-security-shared/               # Multi-language types
└── solidity-security-aws-infrastructure/   # Terraform/K8s
```

---

## 🎯 Common Tasks

### Build a New Service
```bash
# 1. Navigate to service repo
cd /Users/pwner/Git/ABS/solidity-security-<service>

# 2. Check existing code
ls -la
tree src/  # If exists

# 3. Follow Clean Architecture + DDD structure (see CLAUDE-SPEC-KIT.md)

# 4. Create files in this order:
#    a. src/main.py (FastAPI app)
#    b. src/domain/ (business logic)
#    c. src/application/ (use cases)
#    d. src/infrastructure/ (database, external services)
#    e. src/presentation/api/v1/ (endpoints)
#    f. Dockerfile
#    g. tests/

# 5. Build Docker image
docker build -t localhost:8080/library/<service>:latest .

# 6. Push to Harbor
docker push localhost:8080/library/<service>:latest

# 7. Deploy
kubectl apply -k k8s/overlays/local
```

### Add New K8s Templates
```bash
# Already done for all services! See Task 1.10a-COMPLETION.md
# Located in: k8s/base/ and k8s/overlays/local/
```

### Connect Dashboard to Backend
```bash
# 1. Update dashboard API endpoint
cd /Users/pwner/Git/ABS/solidity-security-dashboard
# Edit src/utils/env.ts

# 2. Update API base URL to point to service
# For local: http://localhost:8000
# For K8s: http://<service>.<namespace>.svc.cluster.local:8000
```

### Check Infrastructure Status
```bash
# Cluster
kubectl cluster-info

# All namespaces
kubectl get namespaces | grep -E "(local|monitoring)"

# Specific service
kubectl get pods -n <service>-local
kubectl logs -n <service>-local -l app.kubernetes.io/name=<service>

# Vault status
kubectl exec -n vault-local vault-0 -- vault status

# Database
kubectl exec -n postgresql-local postgresql-0 -- psql -U postgres -c '\l'

# Harbor
curl -u admin:Harbor12345 http://localhost:8080/api/v2.0/projects

# Dashboard
open http://localhost:3000
```

---

## 📋 Architecture Checklist

When building ANY service, ensure:

### Code Structure ✅
- [ ] Follows Clean Architecture + DDD (4 layers: domain, application, infrastructure, presentation)
- [ ] Uses shared library types from solidity-security-shared
- [ ] Has comprehensive tests (unit + integration)
- [ ] Implements all 3 health check endpoints (/health/live, /health/ready, /health/startup)

### Docker ✅
- [ ] Multi-stage build
- [ ] Non-root user (UID 1000)
- [ ] No secrets in image
- [ ] Minimal dependencies
- [ ] Proper tagging

### Kubernetes ✅
- [ ] Has base templates in k8s/base/<service>/
- [ ] Has local overlay in k8s/overlays/local/<service>/
- [ ] Uses External Secrets (no secrets in Git)
- [ ] Proper security contexts
- [ ] Resource limits defined
- [ ] Service uses ClusterIP

### Documentation ✅
- [ ] README.md exists
- [ ] CLAUDE.md with Claude-specific notes
- [ ] API docs (if applicable)
- [ ] Deployment instructions

---

## 🔐 Security Checklist

### NEVER
- ❌ Commit secrets to Git
- ❌ Use root user in containers
- ❌ Skip health checks
- ❌ Ignore security contexts
- ❌ Use `latest` tag in production

### ALWAYS
- ✅ Use Vault for secrets
- ✅ Use External Secrets Operator
- ✅ Run as non-root (UID 1000)
- ✅ Use read-only root filesystem
- ✅ Drop ALL capabilities
- ✅ Implement proper authentication
- ✅ Validate all inputs
- ✅ Use semantic versioning

---

## 💾 Database Quick Reference

### Connection Info (Local)
```bash
Host: postgresql.postgresql-local.svc.cluster.local
Port: 5432
Database: solidity_security
User: postgres
Password: postgres  # From Vault in production
```

### Quick Access
```bash
# Port forward
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432

# Connect with psql
kubectl exec -it -n postgresql-local postgresql-0 -- psql -U postgres

# Run migrations (from service)
alembic upgrade head
```

### Schema Location
See CLAUDE-SPEC-KIT.md for full schema

---

## 🐛 Troubleshooting

### Service won't start
```bash
# 1. Check logs
kubectl logs -n <service>-local -l app.kubernetes.io/name=<service>

# 2. Check events
kubectl get events -n <service>-local --sort-by='.lastTimestamp'

# 3. Check External Secret sync
kubectl get externalsecret -n <service>-local
kubectl describe externalsecret <service>-secret -n <service>-local

# 4. Check Vault secrets exist
kubectl exec -n vault-local vault-0 -- vault kv get secret/solidity-security/<service>/local
```

### Image pull failures
```bash
# 1. Check Harbor is accessible
curl -u admin:Harbor12345 http://localhost:8080/api/v2.0/health

# 2. Check image exists
curl -u admin:Harbor12345 http://localhost:8080/api/v2.0/projects/library/repositories/<service>/artifacts

# 3. Re-push image
docker push localhost:8080/library/<service>:latest
```

### Database connection issues
```bash
# 1. Check PostgreSQL is running
kubectl get pods -n postgresql-local

# 2. Test connection
kubectl run -it --rm debug --image=postgres:17 --restart=Never -- \
  psql -h postgresql.postgresql-local.svc -U postgres -d solidity_security

# 3. Check secrets
kubectl get secret -n <service>-local <service>-secret -o jsonpath='{.data.DATABASE_URL}' | base64 -d
```

---

## 📞 Getting Help

### Documentation Hierarchy
1. **This file** - Quick start
2. **CLAUDE-SPEC-KIT.md** - Comprehensive specifications
3. **Sprint Task files** - Specific task requirements
4. **Architecture docs** - Design decisions
5. **Dev guides** - Implementation patterns

### When Stuck
1. Check existing similar service code
2. Review CLAUDE-SPEC-KIT.md
3. Check Sprint task for specific requirements
4. Ask user for clarification

---

## 🎓 Learning Resources

### Internal Docs (Read First)
- Clean Architecture: `/Users/pwner/Git/ABS/docs/architecture/clean-architecture-decision.md`
- DDD Guide: `/Users/pwner/Git/ABS/solidity-security-docs/development/ddd-implementation-guide.md`
- K8s Structure: `/Users/pwner/Git/ABS/docs/architecture-templates/kubernetes-kustomize-structure-template.md`

### Code Examples
- Best reference: `solidity-security-shared/` - Complete multi-language implementation
- API patterns: Check `solidity-security-api-service/` for FastAPI patterns
- K8s examples: Any service's `k8s/` directory

---

## ⚡ Pro Tips

1. **Read before writing** - Check if code already exists
2. **Copy-paste patterns** - If one service does it, replicate it
3. **Test incrementally** - Build, test, deploy in small steps
4. **Use todo lists** - Track progress with TodoWrite tool
5. **Commit often** - Small, focused commits with clear messages
6. **Update docs** - Keep CLAUDE.md current with decisions

---

**Remember**: This is a guide, not a rulebook. When patterns conflict with specific task requirements, follow the task requirements and update this guide!
