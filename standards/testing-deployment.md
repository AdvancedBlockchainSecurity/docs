# Testing and Deployment Standards

**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## Testing Standards

### Test Before Deploy

**MANDATORY testing sequence:**

```bash
# 1. Unit tests (in service repository)
cd /Users/pwner/Git/ABS/blocksecops-api-service
pytest tests/unit/

# 2. Build Docker image
docker build -t localhost:8080/library/api-service:0.3.7 .

# 3. Push to registry
docker push localhost:8080/library/api-service:0.3.7

# 4. Update Kubernetes manifests (commit first!)
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
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
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local
kubectl rollout status deployment/api-service -n api-service-local

# 3. Force pod restart to ensure new image is used
kubectl delete pod -n api-service-local -l app.kubernetes.io/name=api-service
kubectl rollout status deployment/api-service -n api-service-local

# 4. Test the fix thoroughly
curl http://127.0.0.1:8000/api/v1/analytics/summary | jq '.vulnerability_trends.summary.total_resolved_vulnerabilities'
# Verify the dashboard shows correct numbers
# Test with different scenarios

# 5. ONLY AFTER confirming it works, commit
git add src/presentation/api/v1/endpoints/analytics.py
git commit -m "fix: Correct analytics resolved vulnerabilities count

- Changed net_change calculation to not subtract all-time resolved from time-windowed new
- Without status history, we can't track when vulnerabilities were resolved
- Now shows accurate counts without negative numbers

Tested: Dashboard analytics now shows correct resolved count"

# 6. Push and create PR
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

### CRITICAL: Always Build Docker Images with --no-cache

**MANDATORY:** Docker images MUST be built with the `--no-cache` flag to prevent stale code from being included in builds.

**The Problem:**

Docker uses layer caching to speed up builds. When you change application code but the Dockerfile hasn't changed, Docker may reuse cached layers containing OLD code. This results in deploying images that don't include your latest changes.

**Example of the issue:**

```bash
# Day 1: Build image with code version A
docker build -t api-service:latest .
# Docker caches layers including code version A

# Day 2: Update analytics.py with bug fix (code version B)
vim src/presentation/api/v1/endpoints/analytics.py

# Build image - Docker reuses cached layers!
docker build -t api-service:latest .
# ❌ Image contains OLD code (version A), not your fix (version B)!

# Deploy the image
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local
# ❌ Deployed code doesn't have your fix!

# Test shows bug still exists
curl http://127.0.0.1:8000/api/v1/analytics/summary
# Returns old behavior - your fix isn't deployed
```

**The Solution:**

ALWAYS use `--no-cache` flag when building Docker images for local development and testing:

```bash
✅ CORRECT: Build with --no-cache
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .

# This ensures:
# - All layers rebuilt from scratch
# - Latest code is included
# - No stale cached code
# - Deployed image matches source code
```

**When --no-cache is MANDATORY:**

- **Bug fixes** - Ensuring the fix is actually included
- **Code changes** - Any modifications to application code
- **After editing Python/JS/TS files** - Source code changes
- **Testing fixes locally** - Before committing code
- **When unsure** - Better safe than deploying stale code

**When --no-cache is optional (but still recommended):**

- **Dockerfile changes only** - No application code changes
- **Dependency updates in requirements.txt** - Package changes trigger rebuild anyway
- **CI/CD pipelines** - Automated builds with version control

**Why this matters:**

- **Code Accuracy:** Deployed code must match source code
- **Testing Validity:** Can't test a fix that isn't deployed
- **Debugging Time:** Hours wasted debugging "broken fixes" that aren't deployed
- **Cache Reliability:** Docker cache can be unpredictable with `COPY . /app` commands
- **Development Speed:** Faster to rebuild than debug phantom issues

**Build Time Trade-offs:**

```bash
# With cache (fast but risky)
docker build -t api-service:latest .
# Time: ~10-30 seconds
# Risk: May include stale code

# Without cache (slower but reliable)
docker build --no-cache -t api-service:latest .
# Time: ~2-5 minutes
# Risk: None - guaranteed fresh build
```

**The extra 2-5 minutes is worth it to ensure your code changes are actually deployed.**

**Real-World Example:**

On October 17, 2025, an analytics bug fix was deployed THREE times before working:

1. **First attempt:** Built without `--no-cache`, deployed stale code, bug persisted
2. **Second attempt:** Built with `--no-cache`, BUT Kubernetes cached old image, bug persisted
3. **Third attempt:** Built with `--no-cache` AND deleted pod, fix finally worked

**Complete workflow to ensure code changes deploy:**

```bash
# 1. Make code changes
vim src/presentation/api/v1/endpoints/analytics.py

# 2. Build with --no-cache (MANDATORY)
eval $(minikube docker-env)
docker build --no-cache -t api-service:latest .

# 3. Update deployment
kubectl set image deployment/api-service api-service=api-service:latest -n api-service-local

# 4. Force pod restart (ensures Kubernetes pulls fresh image)
kubectl delete pod -n api-service-local -l app.kubernetes.io/name=api-service

# 5. Wait for rollout
kubectl rollout status deployment/api-service -n api-service-local

# 6. Verify deployed code matches source
kubectl exec -n api-service-local deployment/api-service -- grep -A 2 "net_change" /app/src/presentation/api/v1/endpoints/analytics.py

# 7. Test the fix
curl http://127.0.0.1:8000/api/v1/analytics/summary | jq '.'
```

**Exception for Production:**

In CI/CD pipelines for staging/production, you MAY use Docker cache IF:
- Images are tagged with specific versions (not `latest`)
- Build system tracks source code changes
- Each version is guaranteed a unique build
- Cache invalidation is properly configured

**For local development: ALWAYS use --no-cache. No exceptions.**

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
cd /Users/pwner/Git/ABS/blocksecops-aws-infrastructure
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
