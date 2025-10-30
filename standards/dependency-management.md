# Dependency Management Standards

**Version:** 1.8.0
**Last Updated:** October 20, 2025
**Status:** Active

## Overview

**MANDATORY:** All project dependencies (Python packages, npm packages, Docker base images, security scanners, etc.) MUST be actively maintained and kept up-to-date with latest stable versions.

**Why this matters:**
- **Security:** Outdated dependencies contain known vulnerabilities
- **Stability:** Bug fixes and improvements from active development
- **Support:** Community and vendor support for current versions
- **Compatibility:** Avoid technical debt from deprecated APIs
- **Performance:** Benefit from optimizations in newer releases

## Latest Stable Version Policy

**MANDATORY:** Always use the latest stable version of all dependencies unless a critical bug prevents upgrade.

### Definition of "Latest Stable"

A version is considered "latest stable" if it meets ALL criteria:

✅ **Most Recent Release:**
- The highest version number on the official repository/registry
- Published to official channels (PyPI, npm, Docker Hub, GitHub Releases)

✅ **Stable Status:**
- NOT beta, alpha, RC (release candidate), or preview
- NOT marked as "experimental" or "unstable"
- Examples of stable: `v1.2.3`, `2.4.0`, `0.10.4`
- Examples of unstable: `v1.2.3-beta`, `2.4.0-rc1`, `0.10.5-alpha`

✅ **Not Yanked/Retracted:**
- Not removed from official registries due to critical bugs
- Not marked as "do not use" by maintainers

### When to Update

**Update Frequency:**
- **Security Updates:** Immediately (within 24 hours)
- **Patch Releases:** Within 1 week
- **Minor Releases:** Within 2 weeks
- **Major Releases:** Within 1 month (after validation in staging)

**Update Process:**

```bash
# 1. Check for updates
pip list --outdated  # Python
npm outdated  # Node.js

# 2. Review changelogs
# Visit project repository/release notes
# Check for breaking changes

# 3. Update dependencies
pip install --upgrade <package>  # Python
npm update <package>  # Node.js

# 4. Test thoroughly
# Run test suite, verify functionality

# 5. Commit changes
git add requirements.txt  # or package.json, package-lock.json
git commit -m "chore: Update <package> to v<version>

- Update from v<old> to v<new>
- Includes security fixes / bug fixes / performance improvements
- Tested in local environment"

# 6. Deploy and monitor
```

## Prohibited Dependencies

**CRITICAL RULE:** The following types of dependencies are PROHIBITED and MUST be removed immediately:

### ❌ Deprecated Projects

**Definition:** Projects officially marked as deprecated by maintainers.

**Examples:**
- Projects with "DEPRECATED" in README
- Projects with deprecation notices in documentation
- Projects recommending migration to alternatives

**Action Required:**
1. Identify replacement/alternative
2. Plan migration timeline
3. Remove deprecated dependency
4. Update documentation

**Example - Manticore Scanner Removal:**
```yaml
# Manticore was deprecated because:
- Last release: February 2024
- No longer actively maintained by Trail of Bits
- Recommended alternatives: Mythril, Halmos
- Action: Complete removal from platform (October 2025)
```

### ❌ Retired Projects

**Definition:** Projects that are no longer maintained or supported.

**Indicators:**
- No commits for > 12 months
- No response to issues/PRs for > 6 months
- Maintainer announcement of project end-of-life
- Repository archived on GitHub

**Action Required:**
1. Immediate replacement planning
2. Risk assessment of continuing use
3. Migration to maintained alternative
4. Remove from platform within 30 days

### ❌ Unmaintained Projects

**Definition:** Projects showing signs of abandonment.

**Warning Signs:**
- Last release > 18 months ago
- Critical security issues unfixed for > 3 months
- Maintainer unresponsive
- Dependencies severely outdated
- No roadmap or future plans

**Action Required:**
1. Evaluate project health (OpenSSF Scorecard, activity metrics)
2. Search for maintained forks or alternatives
3. Create migration plan
4. Set deadline for removal

**Example Evaluation:**

| Project | Last Release | Security Issues | Commits (6mo) | Status | Action |
|---------|--------------|-----------------|---------------|--------|--------|
| Slither | Oct 2025 | 0 critical | 150+ | ✅ Active | Keep |
| Manticore | Feb 2024 | 2 unfixed | 5 | ❌ Unmaintained | Remove |
| Mythril | Sep 2025 | 0 critical | 200+ | ✅ Active | Keep |

### ❌ Projects with Critical Unresolved Vulnerabilities

**Definition:** Dependencies with known security vulnerabilities rated HIGH or CRITICAL.

**Sources:**
- GitHub Dependabot alerts
- Snyk vulnerability database
- CVE databases
- Security advisories

**Action Required:**
1. Check if patch is available → Upgrade immediately
2. Check if workaround exists → Implement + document
3. No fix available → Replace dependency
4. Cannot replace → Isolate + monitor + escalate

## Dependency Health Monitoring

**MANDATORY:** Regular monitoring of dependency health and maintenance status.

### Monthly Dependency Audit

**Checklist:**
- [ ] Review Dependabot alerts (GitHub)
- [ ] Check for outdated packages (`pip list --outdated`, `npm outdated`)
- [ ] Verify all dependencies have updates within last 6 months
- [ ] Review any pinned/locked versions for necessity
- [ ] Check for deprecated packages
- [ ] Scan for security vulnerabilities
- [ ] Update lockfiles (requirements.txt, package-lock.json)

### Quarterly Dependency Health Review

**Process:**

1. **Generate Dependency Report:**
```bash
# Python
pip list --format=json > dependencies-python.json

# Node.js
npm list --json > dependencies-node.json

# Analyze
# - Count total dependencies
# - Identify dependencies not updated in 6+ months
# - Flag deprecated/archived projects
```

2. **Evaluate Each Dependency:**
- Last release date
- Security advisory status
- GitHub activity (commits, issues, PRs)
- Maintainer responsiveness
- Community health

3. **Action Items:**
- Upgrade outdated dependencies
- Replace unmaintained dependencies
- Document any exceptions with justification

### Automated Tools (Recommended)

**GitHub Dependabot:**
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "pip"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10

  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
```

**Snyk:**
- Continuous vulnerability scanning
- Automatic PR creation for fixes
- License compliance checking

**Renovate Bot:**
- More configurable than Dependabot
- Supports dependency grouping
- Custom update schedules

## Exception Process

**Limited exceptions** permitted only for **critical bugs in latest versions**.

### When Exceptions Are Allowed

✅ **Permitted:**
- Latest version has critical regression affecting core functionality
- Latest version has security vulnerability (wait for patch)
- Latest version has breaking API changes requiring extensive refactoring (temporary)

❌ **NOT Permitted:**
- "It works fine, don't want to update"
- "Too busy to test new version"
- "Might break something"
- "Old version is more stable" (without evidence)

### Exception Documentation

**Required Fields:**
- Package name and current version
- Latest available version
- Reason for exception (with evidence)
- Link to upstream issue/bug report
- Target upgrade date
- Approval by tech lead
- Review date (must re-evaluate monthly)

**Example:**

```yaml
# In scanner-versions-configmap.yaml or similar
slither:
  version: "0.10.3"  # NOT latest (0.10.4 available)
  exception:
    latest_version: "0.10.4"
    reason: "Critical bug causing false positives on delegatecall patterns"
    issue_url: "https://github.com/crytic/slither/issues/12345"
    approved_by: "tech-lead@company.com"
    approved_date: "2025-10-15"
    target_upgrade: "0.10.5"  # When bug is fixed
    review_date: "2025-11-15"  # Monthly re-evaluation
```

## Lockfile Management

**MANDATORY:** Always commit dependency lockfiles to version control.

### Python Projects

```bash
# Generate/update requirements
pip freeze > requirements.txt

# Or use pip-tools for better control
pip-compile requirements.in > requirements.txt

# Commit lockfile
git add requirements.txt
git commit -m "chore: Update Python dependencies"
```

### Node.js Projects

```bash
# package-lock.json is auto-generated
npm install

# Always commit package-lock.json
git add package-lock.json package.json
git commit -m "chore: Update Node.js dependencies"

# NEVER use --no-save or --no-lock
```

### Docker Images

```dockerfile
# ❌ WRONG - Using 'latest' tag
FROM python:latest

# ✅ CORRECT - Pin to specific version
FROM python:3.11.6-slim

# ✅ BETTER - Pin with SHA256
FROM python:3.11.6-slim@sha256:abc123...
```

## Migration from Deprecated Dependencies

**Process for replacing prohibited dependencies:**

### Step 1: Identify Alternative

**Research:**
- Official migration guide from deprecated project
- Community recommendations
- GitHub "used by" and stars
- Feature parity comparison
- Performance benchmarks

**Criteria for Alternative:**
- ✅ Actively maintained (commits within 3 months)
- ✅ Similar or better functionality
- ✅ Good documentation
- ✅ Active community
- ✅ Security track record
- ✅ Compatible license

### Step 2: Plan Migration

**Create Migration Plan Document:**

```markdown
# Migration from [Old Dependency] to [New Alternative]

## Summary
- Old: Package X v1.2.3 (deprecated Feb 2025)
- New: Package Y v2.0.0 (active, maintained)
- Timeline: 2 weeks
- Risk: Medium

## Justification
- Package X deprecated by maintainer
- No security updates since Dec 2024
- Package Y recommended by maintainer as successor

## API Changes
- Function foo() → bar()
- Parameter old_param → new_param
- Return type changed from dict to dataclass

## Testing Plan
1. Unit tests for migrated code
2. Integration tests
3. Staging environment validation
4. Canary deployment

## Rollback Plan
- Keep old package for 1 sprint
- Feature flag for new implementation
- Can revert via git in < 5 minutes
```

### Step 3: Execute Migration

**Best Practices:**
1. Create feature branch
2. Update dependencies
3. Refactor code for new API
4. Update tests
5. Run full test suite
6. Deploy to staging
7. Monitor for issues
8. Deploy to production
9. Remove old dependency after 1 week

### Step 4: Document Changes

**Update Documentation:**
- README with new dependency
- CHANGELOG with migration notes
- Code comments for breaking changes
- Team notification of changes

## Real-World Example: Manticore Removal

**Context:** Manticore symbolic execution scanner deprecated October 2025.

**Justification:**
- Last maintained release: February 2024
- No active development by Trail of Bits
- Security vulnerabilities unfixed
- Better alternatives available

**Migration:**
| Aspect | Manticore (Removed) | Mythril (Replacement) |
|--------|---------------------|----------------------|
| Status | Deprecated | Actively maintained |
| Last Release | Feb 2024 | Sep 2025 |
| Maintainer | Trail of Bits (stopped) | ConsenSys |
| GitHub Commits (6mo) | 5 | 200+ |
| Security Issues | 2 unfixed | 0 critical |

**Actions Taken:**
1. ✅ Identified alternatives (Mythril, Halmos)
2. ✅ Created removal plan with validation
3. ✅ Removed from 6 repositories
4. ✅ Updated all configurations
5. ✅ Documented migration path for users
6. ✅ Validated with 18 automated tests
7. ✅ Deployed to production

**Results:**
- Security posture improved (active scanner)
- Performance improved (5 min faster scans)
- Maintenance burden reduced
- Zero breaking changes (backward compatible)

## Compliance Checklist

**Dependency Health Verification:**

- [ ] All dependencies use latest stable versions
- [ ] No deprecated packages in use
- [ ] No retired/unmaintained projects
- [ ] No dependencies with last release > 12 months ago
- [ ] All security vulnerabilities addressed
- [ ] Lockfiles committed to version control
- [ ] Dependabot/Renovate configured
- [ ] Monthly dependency audit scheduled
- [ ] Exception documentation up-to-date
- [ ] Migration plans for any deprecated dependencies

**Violations:**
Violations of dependency standards require immediate correction and may block deployments.

---

**See Also:**
- [Tool Metadata ConfigMaps](./tool-metadata-configmaps.md) - Managing third-party tool versions
- [Docker Image Versioning](./docker-image-versioning.md) - Application versioning standards
- [Core Development Rules](./core-development-rules.md) - Development workflow rules
