# Core Development Rules

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.9.0
**Last Updated:** December 4, 2025
**Status:** Active

## Overview

This document defines the critical rules and codebase-first development workflow that are mandatory for all platform development. These are the foundational principles that ensure reproducibility, traceability, and safety.

---

## Critical Rules

### Rule 1: Codebase-First Development

**MANDATORY:** All changes must exist in the codebase. Always test locally before committing.

```
✅ CORRECT WORKFLOW:
1. Create/update configuration files in Git repo folder
2. Apply changes to local Kubernetes cluster
3. Test and verify changes work as expected
4. Fix any issues, repeat steps 2-3 until working
5. Commit changes to version control
6. Push and create pull request
7. Review and merge PR (user account only)
8. Document changes in relevant docs

❌ INCORRECT WORKFLOW:
1. Make ad-hoc changes via kubectl edit/patch
2. Test changes in cluster
3. Forget to update codebase
4. Changes lost on next deployment
```

**Why this matters:**
- **Reproducibility:** Changes not in code cannot be reproduced
- **Collaboration:** Team members unaware of ad-hoc changes
- **Disaster Recovery:** Cannot rebuild platform without code
- **Audit Trail:** No record of what changed or why
- **Debugging:** Impossible to diff actual state vs intended state

**Violations of this rule are considered CRITICAL incidents.**

### Rule 2: Platform Access via Domain

**MANDATORY:** Always access the platform through its domain with HTTPS.

```
✅ CORRECT:
- Server:     https://app.blocksecops.local
- Production: https://app.blocksecops.com

❌ INCORRECT:
- http://127.0.0.1:3000
- http://localhost:8000
- http://app.blocksecops.local (HTTP — must use HTTPS)
```

All traffic goes through Traefik ingress with TLS. HTTP automatically redirects to HTTPS.

**CORS Configuration:**

CORS origins are managed via ConfigMap (source of truth), not hardcoded in application code:

```yaml
# k8s/overlays/local/api-service/configmap-patch.yaml
cors_origins: "https://app.blocksecops.local"
allowed_hosts: "app.blocksecops.local"
dashboard_base_url: "https://app.blocksecops.local"
```

The base deployment (`k8s/base/api-service/deployment.yaml`) maps these ConfigMap keys to environment variables. Application defaults in `config.py` target production (`app.blocksecops.com`).

See [Domain Management Standards](./domain-management.md) for the full source of truth chain and switching between environments.

### Rule 3: Restart Pods After Code Changes

**MANDATORY:** After merging code changes or pulling latest code, pods must be restarted to pick up the new changes.

```
✅ CORRECT WORKFLOW:
1. Create feature branch from main
2. Make code changes and commit to feature branch
3. Push feature branch and create pull request
4. Review and merge PR (user account only)
5. Pull latest code: git pull origin main
6. Build and push new Docker image (if image-based deployment)
7. Restart deployment: kubectl rollout restart deployment/<service> -n <namespace>
8. Wait for rollout: kubectl rollout status deployment/<service> -n <namespace>
9. Verify changes are active

❌ INCORRECT WORKFLOW:
1. Make changes directly on main branch
2. Commit and push to main
3. Pull latest code
4. Assume running pods will pick up changes automatically
5. Wonder why new features don't work
```

**When Pod Restarts Are Required:**
- After merging code changes (API service, workers, etc.)
- After pulling latest code from main branch
- After configuration changes in ConfigMaps or Secrets
- After updating environment variables
- After dependency updates (requirements.txt, package.json, etc.)

**Example - Restarting Services After Code Merge:**

```bash
# 1. Pull latest code
cd /Users/pwner/Git/ABS/blocksecops-api-service
git checkout main
git pull

# 2. Restart the API service pod to pick up changes
kubectl rollout restart deployment/api-service -n api-service-local

# 3. Wait for rollout to complete
kubectl rollout status deployment/api-service -n api-service-local

# 4. Verify new code is running
kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service --tail=20

# 5. Verify API health
curl -s http://127.0.0.1:8000/api/v1/health/ready | jq '.'
```

**Common Services That Need Restart:**

```bash
# API Service (after backend code changes)
kubectl rollout restart deployment/api-service -n api-service-local

# Data Service (after data processing code changes)
kubectl rollout restart deployment/data-service -n data-service-local

# Tool Integration (after scanner integration changes)
kubectl rollout restart deployment/tool-integration -n tool-integration-local

# Workers (after background job code changes)
kubectl rollout restart deployment/celery-worker -n workers-local
```

**Why This Matters:**
- **Stale Code:** Running pods continue using old code until restarted
- **Testing Failures:** New features won't work if pods aren't restarted
- **Confusing Bugs:** Seeing old behavior when expecting new fixes
- **Wasted Time:** Debugging issues that don't exist in the new code

**Port Forward Note:** After restarting API service, you may need to restart the port-forward:

```bash
# Kill old port-forward
ps aux | grep "port-forward.*svc/api-service" | grep -v grep | awk '{print $2}' | xargs kill

# Start new port-forward
kubectl port-forward -n api-service-local svc/api-service 8000:8000 > /tmp/pf-api-service.log 2>&1 &
```

---

## Codebase-First Development

### What Must Be in Code

**ALL of the following MUST exist in Git before being applied:**

1. **Kubernetes Manifests**
   - Deployments, Services, ConfigMaps
   - Secrets (via External Secrets, not values)
   - Ingress rules, Network Policies
   - RBAC roles and bindings

2. **Configuration Files**
   - Application configs (`.env.example`, `config.yaml`)
   - Infrastructure configs (Terraform, Kustomize)
   - Build configs (Dockerfiles, build scripts)

3. **Database Changes**
   - Migration scripts
   - Schema definitions
   - Seed data scripts

4. **Infrastructure Changes**
   - Terraform modules and variables
   - Helm charts and values
   - Kustomize bases and overlays

5. **Scripts and Automation**
   - Deployment scripts
   - Backup/restore scripts
   - Maintenance scripts

### Workflow for Platform Changes

#### Making Kubernetes Changes

```bash
# 1. NEVER do this directly
kubectl edit deployment api-service -n api-service-local  ❌

# 2. ALWAYS do this instead
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service

# 3. Edit the manifest file
vim deployment-patch.yaml

# 4. Commit the change
git add deployment-patch.yaml
git commit -m "Update API service memory limits

- Increase memory limit from 512Mi to 1Gi
- Required for handling larger scan payloads

Refs: #123"

# 5. Apply from code
kubectl apply -k .

# 6. Verify change
kubectl get deployment api-service -n api-service-local -o yaml | grep memory
```

#### Making Configuration Changes

```bash
# 1. Update configuration file in repository
cd /Users/pwner/Git/ABS/blocksecops-api-service
vim src/config.py

# 2. Update corresponding ConfigMap
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
vim configmap-patch.yaml

# 3. Commit both changes together
git add ../../blocksecops-api-service/src/config.py
git add configmap-patch.yaml
git commit -m "Add request timeout configuration

- Add REQUEST_TIMEOUT_SECONDS to config
- Default: 30 seconds
- Configurable via environment variable"

# 4. Rebuild and deploy
cd /Users/pwner/Git/ABS/blocksecops-api-service
docker build -t localhost:8080/library/api-service:0.3.7 .
docker push localhost:8080/library/api-service:0.3.7

# 5. Apply ConfigMap changes
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
kubectl apply -k k8s/overlays/local/api-service

# 6. Restart deployment to pick up changes
kubectl rollout restart deployment api-service -n api-service-local
```

#### Emergency Hotfixes

**Even in emergencies, follow this process:**

```bash
# 1. Make temporary fix (if absolutely necessary)
kubectl patch deployment api-service -n api-service-local \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"api-service","resources":{"limits":{"memory":"2Gi"}}}]}}}}'

# 2. IMMEDIATELY document the change
echo "EMERGENCY HOTFIX: Increased API service memory to 2Gi at $(date)" >> HOTFIX.log

# 3. Within 1 hour, update the codebase
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure/k8s/overlays/local/api-service
vim deployment-patch.yaml
git add deployment-patch.yaml
git commit -m "HOTFIX: Increase API service memory to 2Gi

Emergency fix applied at [timestamp]
Root cause: Memory leak in scan result processing
Permanent fix tracked in: #456"

# 4. Verify code matches running state
kubectl diff -k k8s/overlays/local/api-service
```

### Documentation Requirements for Changes

**Every platform change MUST include:**

1. **Commit Message** with:
   - Clear description of what changed
   - Why the change was necessary
   - Impact assessment
   - Reference to issue/ticket (if applicable)

2. **Update Summary Document** (for significant changes):
   ```markdown
   # Change Summary: [Brief Title]

   **Date:** YYYY-MM-DD
   **Author:** [Your Name]
   **Services Affected:** api-service, data-service

   ## What Changed
   - [Specific change 1]
   - [Specific change 2]

   ## Why
   [Rationale for the change]

   ## Impact
   - Performance: [impact]
   - Availability: [impact]
   - Dependencies: [impact]

   ## Rollback Plan
   [How to revert if needed]

   ## Verification
   - [ ] Code committed and pushed
   - [ ] Changes applied to local environment
   - [ ] Tests passing
   - [ ] Monitoring confirms expected behavior
   ```

3. **Update Relevant Docs**:
   - Architecture docs if structure changed
   - Deployment guides if process changed
   - Troubleshooting guides if behavior changed

---

## Related Standards

- [Version Control Standards](./version-control-standards.md) - Git workflow and branch management
- [Testing & Deployment](./testing-deployment.md) - Testing and deployment processes
- [Documentation Standards](./documentation-standards.md) - Documentation requirements
- [Compliance Checklist](./compliance-checklist.md) - Daily compliance checks
