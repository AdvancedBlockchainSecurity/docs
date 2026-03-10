# Testing and Deployment Standards

**Version:** 2.0.0
**Last Updated:** March 10, 2026
**Status:** Active

## Testing Standards

### Test Before Deploy

**MANDATORY testing sequence:**

```bash
# 1. Unit tests (in service repository)
cd blocksecops-api-service
pytest tests/unit/

# 2. Build Docker image
docker build -t ${REGISTRY}/blocksecops/api-service:${VERSION} .

# 3. Push to registry
docker push ${REGISTRY}/blocksecops/api-service:${VERSION}

# 4. Update Kubernetes manifests (commit first!)
cd <infrastructure-repo>
vim k8s/overlays/local/api-service/kustomization.yaml
git add .
git commit -m "Update API service to v0.3.7"

# 5. Deploy
kubectl apply -k k8s/overlays/local/api-service

# 6. Wait for rollout
kubectl rollout status deployment api-service -n api-service-local

# 7. Integration tests
curl http://127.0.0.1:8000/api/v1/health/live
curl http://127.0.0.1:8000/api/v1/health/ready

# 8. Verify logs
kubectl logs -n api-service-local -l app.kubernetes.io/name=api-service --tail=50
```

### CRITICAL: Do Not Rollback Working Deployments

**IMPORTANT:** If you have already deployed working code and then realize you forgot to commit it to version control first:

```bash
✅ CORRECT ACTION:
1. Leave the working deployment running
2. Commit the code changes that match what's deployed
3. Push commits and create pull request
4. Document what was deployed and when

❌ INCORRECT ACTION:
1. Rollback the working deployment
2. Commit the code
3. Redeploy

**Why this matters:**
- **Service Availability:** Rolling back working code causes unnecessary downtime
- **User Experience:** Users lose access to working features during rollback
- **Development Time:** Wasted time rolling back and redeploying
- **Risk Introduction:** Additional deployment increases risk of errors

**The proper workflow is:**
1. **If deployment is working:** Keep it running, commit the code to match
2. **If deployment is broken:** Follow the rollback procedure below
```

### CRITICAL: Test Before Committing Fixes

**MANDATORY:** When fixing bugs or issues, ALWAYS test and confirm the fix works BEFORE committing the code.

```bash
✅ CORRECT WORKFLOW:
1. Identify the issue and root cause
2. Make code changes to fix the issue
3. Build and deploy the fix to local environment
4. Test and verify the fix resolves the issue
5. Once confirmed working, commit the code changes
6. Push commits and create pull request

❌ INCORRECT WORKFLOW:
1. Identify the issue
2. Make code changes
3. Commit the code immediately
4. Deploy and test
5. Discover the fix doesn't work or causes new issues
6. Need to revert commit or make additional commits
```

**Why this matters:**
- **Commit Quality:** Commits should represent working, tested code
- **Git History:** Cleaner history without fix-the-fix commits
- **Code Review:** Reviewers see tested, working code
- **Confidence:** Know the fix works before committing
- **Rollback Safety:** Each commit is a known-working state

**Example - Fixing Analytics Issue:**

```bash
# 1. Make the fix
vim src/presentation/api/v1/endpoints/analytics.py

# 2. Build and deploy (DON'T COMMIT YET)
REGISTRY="${REGISTRY:?REGISTRY not set}"
docker build -t ${REGISTRY}/blocksecops/api-service:0.4.2 .
docker push ${REGISTRY}/blocksecops/api-service:0.4.2
kubectl rollout restart deployment/api-service -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 3. Test the fix thoroughly
curl http://127.0.0.1:8000/api/v1/analytics/summary | jq '.vulnerability_trends.summary.total_resolved_vulnerabilities'
# Verify the dashboard shows correct numbers
# Test with different scenarios

# 4. ONLY AFTER confirming it works, commit
git add src/presentation/api/v1/endpoints/analytics.py
git commit -m "fix: Correct analytics resolved vulnerabilities count

- Changed net_change calculation to not subtract all-time resolved from time-windowed new
- Without status history, we can't track when vulnerabilities were resolved
- Now shows accurate counts without negative numbers

Tested: Dashboard analytics now shows correct resolved count"

# 5. Push to registry and create PR
docker push ${REGISTRY}/blocksecops/api-service:0.4.2
git push
```

**When to commit before testing:**
- Documentation changes (no risk of breaking functionality)
- Configuration file updates that don't affect running systems
- Non-functional refactoring with comprehensive test coverage

**Always test before committing:**
- Bug fixes (verify they actually fix the issue)
- New features (verify they work as intended)
- API changes (verify backward compatibility)
- Database migrations (verify data integrity)
- Deployment configuration changes (verify services remain healthy)

### Docker Build Caching with Container Registry

**With a container registry and versioned tags, `--no-cache` is no longer required for most builds.**

**Why `--no-cache` is no longer mandatory:**

With a container registry:
- Each version gets a unique tag (0.4.0, 0.4.1, etc.)
- Images are pushed to the registry with versioned tags
- Kubernetes pulls images from the registry by tag
- The original Docker cache issue (stale `:latest` images) is solved by versioned tags

**Standard Build Workflow:**

```bash
REGISTRY="${REGISTRY:?REGISTRY not set}"

# 1. Build with new version tag
docker build -t ${REGISTRY}/blocksecops/api-service:0.4.1 .

# 2. Push to registry
docker push ${REGISTRY}/blocksecops/api-service:0.4.1

# 3. Restart deployment
kubectl rollout restart deployment/api-service -n api-service-local
```

**When to use `--no-cache`:**

Use `--no-cache` only in these specific scenarios:

- **Debugging build issues** - When you suspect cached layers are causing problems
- **Rebuilding same version tag** - If you must rebuild without incrementing version
- **Fresh dependency downloads** - When you need to update all dependencies
- **CI/CD initial builds** - First build in a clean environment

```bash
# Use --no-cache when needed
docker build --no-cache -t api-service:0.4.1 .
```

**Build Time Comparison:**

```bash
# With cache (fast, safe with versioned tags)
docker build -t api-service:0.4.1 .
# Time: ~10-30 seconds

# Without cache (slower, guaranteed fresh)
docker build --no-cache -t api-service:0.4.1 .
# Time: ~2-5 minutes
```

**Best Practice:** Increment version tags for each code change. This eliminates caching ambiguity and provides clear version tracking.

### Rollback Procedure

**If tests fail after deployment:**

```bash
# 1. Check what version is currently deployed
kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'

# 2. Rollback Kubernetes deployment
kubectl rollout undo deployment api-service -n api-service-local

# 3. Verify rollback
kubectl rollout status deployment api-service -n api-service-local

# 4. Update code to match deployed version
cd <infrastructure-repo>
git revert HEAD
git push

# 5. Document the rollback
echo "Rolled back API service from 0.3.7 to 0.3.6 at $(date) - reason: [explain]" >> ROLLBACK.log
```

## Deployment Workflow

### Standard Deployment Process

**For ALL platform changes:**

```
1. CODE UPDATE
   ├─ Update service code
   ├─ Update Kubernetes manifests
   ├─ Update configuration files
   └─ Commit all changes

2. BUILD
   ├─ Build Docker image
   ├─ Tag with semantic version
   └─ Push to registry

3. DEPLOY
   ├─ Apply Kubernetes changes from code
   ├─ Wait for rollout completion
   └─ Verify health checks

4. TEST
   ├─ Run integration tests
   ├─ Check logs for errors
   └─ Verify expected behavior

5. DOCUMENT
   ├─ Update deployment log
   ├─ Update relevant documentation
   └─ Communicate to team (if significant)
```

### Deployment Checklist

Before deploying any change:

- [ ] All changes committed to Git
- [ ] Changes pushed to remote repository
- [ ] Docker image built and pushed
- [ ] Kubernetes manifests updated in code
- [ ] Version numbers incremented (if applicable)
- [ ] Tests passing locally
- [ ] Rollback plan documented
- [ ] Team notified (if significant change)

After deploying:

- [ ] Deployment successful
- [ ] Health checks passing
- [ ] No errors in logs
- [ ] Integration tests passing
- [ ] Monitoring shows expected metrics
- [ ] Documentation updated
- [ ] Deployment logged

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Docker Image Versioning](./docker-image-versioning.md) - Docker image versioning standards
- [Version Control Standards](./version-control-standards.md) - Git workflow and commits
