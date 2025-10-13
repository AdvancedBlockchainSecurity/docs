# BlockSecOps Platform - Release Process

**Last Updated**: October 12, 2025
**Status**: Active
**Owner**: Platform Engineering Team

---

## Overview

This document describes the complete release process for BlockSecOps Platform services. All services follow a standardized release workflow using semantic versioning and automated CI/CD pipelines.

## Semantic Versioning

BlockSecOps Platform uses [Semantic Versioning 2.0.0](https://semver.org/) for all releases.

### Version Format

```
MAJOR.MINOR.PATCH[-PRERELEASE]

Examples:
- 1.0.0         (stable release)
- 1.2.3         (stable release)
- 2.0.0-alpha.1 (pre-release)
- 2.0.0-beta.2  (pre-release)
- 2.0.0-rc.1    (release candidate)
```

### Version Increment Rules

- **MAJOR** (X.0.0): Breaking API changes, incompatible updates
- **MINOR** (0.X.0): New features, backwards-compatible
- **PATCH** (0.0.X): Bug fixes, security patches
- **PRERELEASE** (X.Y.Z-alpha/beta/rc): Development/testing versions

## Release Workflow

### Automated Release Pipeline

All services use a standardized GitHub Actions workflow (`.github/workflows/release.yml`) that:

1. ✅ **Validates** version consistency (VERSION file vs git tag)
2. ✅ **Tests** full test suite with coverage requirements (>75%)
3. ✅ **Scans** for security vulnerabilities (safety, bandit, Trivy)
4. ✅ **Builds** multi-architecture Docker images (amd64, arm64)
5. ✅ **Generates** automatic changelog from git commits
6. ✅ **Creates** GitHub release with release notes
7. ✅ **Deploys** to production (stable releases only)
8. ✅ **Notifies** team of deployment status

### Release Types

#### 1. Stable Release (Production)

**Characteristics**:
- Version format: `v1.2.3` (no prerelease suffix)
- Automatically deployed to production
- Full CI/CD pipeline execution
- Multi-architecture Docker builds
- Changelog generation and GitHub release creation

**Process**:
```bash
# 1. Update VERSION file
echo "1.2.3" > VERSION

# 2. Commit version change
git add VERSION
git commit -m "Release v1.2.3

- Added feature X
- Fixed bug Y
- Updated dependencies Z"

# 3. Create and push git tag
git tag v1.2.3
git push origin v1.2.3

# 4. Monitor release workflow
# Visit: https://github.com/blocksecops/[service]/actions
```

**Automatic Actions**:
- ✅ Tests run on Python 3.13.7 with PostgreSQL 16.10 and Redis 7.2.4
- ✅ Coverage verified (minimum 75%)
- ✅ Security scans (dependencies and source code)
- ✅ Docker images pushed to `ghcr.io` with tags:
  - `ghcr.io/blocksecops/[service]:1.2.3`
  - `ghcr.io/blocksecops/[service]:1.2` (major.minor)
  - `ghcr.io/blocksecops/[service]:1` (major)
  - `ghcr.io/blocksecops/[service]:latest`
- ✅ GitHub release created with changelog
- ✅ Production deployment initiated

#### 2. Pre-Release (Testing/Staging)

**Characteristics**:
- Version format: `v1.2.3-beta.1`, `v2.0.0-rc.1`
- **NOT** deployed to production automatically
- Deployed to staging/testing environments only
- Marked as "Pre-release" in GitHub releases

**Process**:
```bash
# 1. Update VERSION file with prerelease suffix
echo "1.2.3-beta.1" > VERSION

# 2. Commit version change
git add VERSION
git commit -m "Pre-release v1.2.3-beta.1 for testing"

# 3. Create and push git tag
git tag v1.2.3-beta.1
git push origin v1.2.3-beta.1
```

**Automatic Actions**:
- ✅ Full test suite execution
- ✅ Security scans
- ✅ Docker images pushed with prerelease tags:
  - `ghcr.io/blocksecops/[service]:1.2.3-beta.1`
  - `ghcr.io/blocksecops/[service]:latest-beta` (optional)
- ✅ GitHub release created (marked as pre-release)
- ⏭️ **Production deployment skipped**

**Prerelease Keywords** (auto-detected):
- `alpha` - Early development, unstable
- `beta` - Feature complete, testing phase
- `rc` - Release candidate, final testing

## Service-Specific Release Instructions

### Python Services

**Services**:
- blocksecops-api-service
- blocksecops-tool-integration
- blocksecops-intelligence-engine
- blocksecops-orchestration
- blocksecops-data-service
- blocksecops-notification

**Requirements**:
- Python 3.13.7
- VERSION file at repository root
- requirements/base.txt, requirements/test.txt
- pytest with coverage >= 75%

**Test Command**:
```bash
pytest tests/ -v \
  --cov=src \
  --cov-report=xml \
  --cov-fail-under=75
```

**Docker Build**:
```yaml
# Multi-stage Dockerfile required
FROM python:3.13.7-slim as builder
# ... build stage ...

FROM python:3.13.7-slim as runtime
# ... runtime stage ...
```

### TypeScript Services

**Services**:
- blocksecops-dashboard
- blocksecops-findings
- blocksecops-analysis
- blocksecops-ui-core (library)

**Requirements**:
- Node.js 24.9+ (LTS)
- VERSION file at repository root
- package.json with version field
- npm test with coverage

**Release Notes**:
- `blocksecops-ui-core` is a shared library, no Docker image built

### Rust Services

**Services**:
- blocksecops-contract-parser

**Requirements**:
- Rust 1.90+ (stable)
- Cargo.toml with version field
- cargo test passing

## Release Checklist

### Pre-Release (Developer)

- [ ] All tests passing locally
- [ ] Code reviewed and approved
- [ ] Documentation updated
- [ ] CHANGELOG.md prepared (optional, auto-generated)
- [ ] Breaking changes documented (for major versions)
- [ ] Migration guide created (if needed)
- [ ] VERSION file updated
- [ ] Git tag format validated (`v*.*.*`)

### During Release (Automated)

- [ ] VERSION file matches git tag
- [ ] Full test suite passes (>75% coverage)
- [ ] Security scans complete (no critical/high issues)
- [ ] Docker images build successfully
- [ ] Multi-arch builds complete (amd64, arm64)
- [ ] Container vulnerability scan passes
- [ ] GitHub release created
- [ ] Changelog generated

### Post-Release (DevOps/SRE)

- [ ] Production deployment verified (stable releases only)
- [ ] Health checks passing
- [ ] Monitoring alerts reviewed
- [ ] Performance metrics checked
- [ ] Rollback plan confirmed
- [ ] Team notified (Slack/email)
- [ ] Documentation updated

## Rollback Procedure

### Quick Rollback (< 5 minutes)

If the release causes critical issues:

```bash
# 1. Identify previous stable version
PREVIOUS_VERSION="1.2.2"

# 2. Rollback Kubernetes deployment
kubectl set image deployment/[service-name] \
  [service-name]=ghcr.io/blocksecops/[service]:${PREVIOUS_VERSION} \
  --namespace=production

# 3. Monitor rollout
kubectl rollout status deployment/[service-name] --namespace=production

# 4. Verify health
kubectl get pods -n production -l app=[service-name]
curl -f https://api.blocksecops.com/health
```

### Full Rollback (with database migrations)

If database migrations need to be reverted:

```bash
# 1. Rollback deployment (as above)

# 2. Access database pod
kubectl exec -it postgresql-0 -n production -- psql -U postgres

# 3. Run Alembic downgrade
alembic downgrade -1  # or alembic downgrade [revision]

# 4. Verify data integrity
# Run validation queries
```

## Emergency Hotfix Process

For critical security or bug fixes that cannot wait for normal release cycle:

### 1. Create Hotfix Branch

```bash
# Branch from production tag
git checkout v1.2.3
git checkout -b hotfix/1.2.4

# Make minimal changes
git add [files]
git commit -m "Hotfix: Critical security patch for CVE-XXXX"
```

### 2. Fast-Track Testing

```bash
# Run critical tests only
pytest tests/security/ -v
pytest tests/integration/ -v -m critical

# Manual smoke testing required
```

### 3. Release Hotfix

```bash
# Update VERSION
echo "1.2.4" > VERSION
git add VERSION
git commit -m "Release v1.2.4 - Emergency hotfix"

# Tag and push
git tag v1.2.4
git push origin v1.2.4

# Merge back to main
git checkout main
git merge hotfix/1.2.4
git push origin main
```

## Monitoring Release Health

### Key Metrics to Monitor

**During Deployment** (first 15 minutes):
- Pod restart count (should be 0)
- Memory usage (< 80% of limit)
- CPU usage (< 70% of limit)
- Response time (< 200ms p95)
- Error rate (< 0.1%)

**Post-Deployment** (first hour):
- Request rate (should match baseline)
- Success rate (> 99.9%)
- Database connection pool (healthy)
- Cache hit rate (> 80%)

**Alerts to Watch**:
```yaml
# Prometheus alerts
- ServiceDown: Service unavailable
- HighErrorRate: Error rate > 5%
- HighLatency: p95 response time > 500ms
- DatabaseConnectionFailure: Cannot connect to database
- HighMemoryUsage: Memory > 90%
```

### Rollback Decision Matrix

| Metric | Threshold | Action |
|--------|-----------|--------|
| Error rate | > 5% for 5 minutes | Consider rollback |
| Error rate | > 10% for 1 minute | Immediate rollback |
| Response time | p95 > 1s for 10 minutes | Investigate, prepare rollback |
| Response time | p95 > 5s for 2 minutes | Immediate rollback |
| Memory usage | > 95% for 5 minutes | Immediate rollback |
| Crash loop | 3+ restarts in 5 minutes | Immediate rollback |

## Release Schedule

### Regular Release Windows

**Stable Releases**:
- **Tuesday/Wednesday**: Preferred release days
- **10:00 AM - 2:00 PM PST**: Release window
- **Avoid Friday releases**: Limited support coverage over weekend

**Pre-Releases**:
- Anytime during business hours
- Deployed to staging environment automatically

### Release Freeze Periods

**No releases during**:
- Major holidays
- Company-wide events
- Known high-traffic periods
- Ongoing incidents

## Troubleshooting Release Issues

### Common Issues and Solutions

#### Issue: VERSION file mismatch

**Error**: `VERSION file (1.2.3) does not match git tag (1.2.4)`

**Solution**:
```bash
# Delete incorrect tag
git tag -d v1.2.4
git push --delete origin v1.2.4

# Fix VERSION file
echo "1.2.4" > VERSION
git add VERSION
git commit --amend

# Recreate tag
git tag v1.2.4
git push origin v1.2.4
```

#### Issue: Docker build fails

**Error**: `ImportError: No module named 'src.module'`

**Solution**:
```bash
# Ensure all files are committed before building
git status  # Check for untracked files
git add [missing-files]
git commit -m "Add missing files"
git tag -f v1.2.3  # Force update tag
git push --force origin v1.2.3
```

#### Issue: Tests fail in CI but pass locally

**Common Causes**:
- Environment variable differences
- Database state differences
- Timezone issues
- Async test flakiness

**Solution**:
```bash
# Run tests in CI-like environment
docker-compose -f docker-compose.test.yml up --abort-on-container-exit

# Check GitHub Actions logs
# https://github.com/blocksecops/[service]/actions
```

#### Issue: Security scan blocks release

**Error**: `Trivy found 5 HIGH vulnerabilities`

**Solution**:
```bash
# Update dependencies locally
pip install --upgrade [package]  # Python
npm update [package]              # Node.js
cargo update [package]            # Rust

# Re-run security scan
trivy image [image-name]

# If false positive, add to .trivyignore
echo "CVE-XXXX-YYYY" >> .trivyignore
```

## Contact and Support

**Release Engineering Team**:
- Slack: #releases
- Email: releases@blocksecops.com
- On-call: Check PagerDuty rotation

**Escalation Path**:
1. Check this documentation
2. Search GitHub issues and past releases
3. Post in #releases Slack channel
4. Tag @release-engineering
5. Page on-call engineer (production incidents only)

## Related Documentation

- [CI/CD Automation Guide](/Users/pwner/Git/ABS/blocksecops-docs/development/ci-cd-automation.md)
- [Docker Image Standards](/Users/pwner/Git/ABS/docs/DOCKER-IMAGE-STANDARDS.md)
- [Security Hardening Guide](/Users/pwner/Git/ABS/docs/security/)
- [Deployment Notes (per service)](/Users/pwner/Git/ABS/blocksecops-docs/deployment/)
- [Sprint Plan](/Users/pwner/Git/ABS/docs/sprint-plan_new.md)

## Changelog

| Date | Author | Changes |
|------|--------|---------|
| 2025-10-12 | Claude Code | Initial release process documentation |
| 2025-10-12 | Claude Code | Added tag-based release workflow details |
| 2025-10-12 | Claude Code | Documented rollback and hotfix procedures |

---

**Last Review**: October 12, 2025
**Next Review**: Before production launch (Sprint 18)
