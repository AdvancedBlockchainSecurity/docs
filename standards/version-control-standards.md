# Version Control Standards

**Version:** 1.9.0
**Last Updated:** 2026-06-21
**Status:** Active

## Owner Approval Required

**MANDATORY:** All git operations — branch creation, commits, pushes, PR creation, and PR merging — require explicit approval from the repository owner before execution. No automated tooling or agent may perform these operations without the owner's direct sign-off. See [Core Development Rules — Rule 0](./core-development-rules.md#rule-0-gitops-requires-owner-approval).

## Commit Message Format

**MANDATORY format for all commits:**

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, no logic change)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `hotfix`: Emergency production fix

**Example:**

```
feat: Add request timeout configuration to API service

- Add REQUEST_TIMEOUT_SECONDS to configuration
- Default timeout: 30 seconds
- Configurable via TIMEOUT environment variable
- Add validation for timeout range (1-300 seconds)

This prevents hung requests from blocking workers during
long-running scan operations.

Refs: #123
```

## Linear Ticket Reference

When a change is shipped through the `/ship` cycle, the commit body must end with the Linear ticket ID on its own line as the last element of the footer. This is the bidirectional link between the Git commit and the Linear ticket in the `Advanced Blockchain Security` team (key `ADV`).

**Reference (ticket remains open after this commit):**

```
Refs: ADV-NNN
```

**Close (this commit fully resolves the ticket):**

```
Closes: ADV-NNN
```

If a single commit addresses multiple tickets, list each reference on its own line:

```
Refs: ADV-12
Refs: ADV-13
```

**Full example with Linear ticket reference:**

```
fix(api-service): reject AI scan trigger when org flag is disabled

- Return 400 ai_org_disabled instead of silently queuing the scan
- Added test_ai_scan_org_flag_disabled in test_scan_endpoints.py
- Updated docs/workflows/ai-scan-trigger-workflow.md Phase 1 constraints

Refs: ADV-42
```

**When is this required?** Any commit that goes through `/ship` Phase 6. Commits from hotfixes or pre-/ship changes use `Refs: #NNN` (GitHub issue number) as shown in the legacy example below. Do not mix `ADV-` and `#NNN` formats in the same footer.

**See also:** `docs/workflows/ship-cycle-workflow.md` for the full Linear ticket lifecycle.

---

## Branch Naming

**Standard branch naming:**

```
<type>/<short-description>

Examples:
- feat/add-timeout-config
- fix/cors-127-address
- docs/update-deployment-guide
- hotfix/memory-leak-api-service
```

## Git Workflow - Feature Branch Model

**CRITICAL:** NEVER commit directly to main branch. ALL changes MUST go through feature branches and pull requests.

```
✅ CORRECT WORKFLOW:
1. Create feature branch from main
2. Make changes and commit to feature branch
3. Push feature branch to remote
4. Create pull request
5. Review and merge PR (user account only, NEVER as Claude)
6. Delete feature branch after merge

❌ INCORRECT WORKFLOW:
1. Make changes directly on main branch
2. Commit to main branch
3. Push directly to main
```

**Why this matters:**
- **Code Review:** All changes reviewed before merging to main
- **Quality Control:** Prevents broken code from reaching main
- **Audit Trail:** Clear history of what changed and why
- **Collaboration:** Team members can review and discuss changes
- **Rollback Safety:** Easy to revert problematic changes
- **CI/CD Integration:** Automated tests run before merge

**MANDATORY: This is the standard git workflow. Violations are unacceptable.**

### Step-by-Step Feature Branch Workflow

**1. Start New Feature/Fix:**

```bash
# Ensure you're on main and up to date
git checkout main
git pull origin main

# Create and switch to feature branch
git checkout -b feat/add-scan-filtering
# or
git checkout -b fix/vulnerability-status-update
# or
git checkout -b docs/update-api-guide
```

**2. Make Changes and Commit:**

```bash
# Make your code changes
vim src/api/endpoints/scans.py

# Stage changes
git add src/api/endpoints/scans.py

# Commit with descriptive message
git commit -m "feat: Add filtering by severity to scan endpoint

- Add severity query parameter to /api/v1/scans
- Support multiple severity filters (e.g., ?severity=high,critical)
- Add validation for severity values
- Update API documentation

Allows users to filter scans by vulnerability severity.

Refs: #234"

# Continue making changes as needed
# Commit frequently with clear messages
```

**3. Push Feature Branch:**

```bash
# Push branch to remote (first time)
git push -u origin feat/add-scan-filtering

# Subsequent pushes
git push
```

**3.5. Test Changes (User Testing & API Testing):**

```bash
# Deploy to local environment
make deploy-local

# Perform API testing with actual endpoints
curl -X POST http://localhost:8001/api/v1/scans?severity=high,critical

# User testing - verify functionality works as expected
# - Test through UI if applicable
# - Verify error handling
# - Check edge cases
# - Validate responses
```

**3.6. Update Documentation (MANDATORY):**

**CRITICAL: Documentation MUST be updated AFTER user/API testing but BEFORE creating pull request.**

Documentation should be updated in the following locations based on change type:

```bash
# General documentation (architecture, standards, processes)
/Users/pwner/Git/ABS/docs/*

# Task-specific documentation (sprint tasks, implementation plans)
/Users/pwner/Git/ABS/TaskDocs-Apogee/*

# Technical documentation (API guides, deployment, development guides)
/Users/pwner/Git/ABS/blocksecops-docs/*
```

**Documentation Update Requirements:**

1. **API Changes** - Update relevant files in:
   - `blocksecops-docs/api/endpoints-reference.md` (endpoint documentation)
   - `blocksecops-docs/api/dashboard-integration.md` (if affects frontend)
   - Include request/response examples from actual testing

2. **Architecture Changes** - Update:
   - `blocksecops-docs/architecture/` (system architecture)
   - `docs/architecture-templates/` (if templates affected)
   - Add diagrams if needed

3. **Deployment Changes** - Update:
   - `blocksecops-docs/deployment/` (deployment guides)
   - `blocksecops-docs/local-development/` (local setup)
   - Include configuration examples

4. **Feature Implementation** - Document in:
   - `TaskDocs-Apogee/blocksecops/` (implementation summary)
   - Create completion report for significant features
   - Update relevant phase/sprint documentation

5. **Development Process Changes** - Update:
   - `docs/PLATFORM-DEVELOPMENT-STANDARDS.md` (this file)
   - `blocksecops-docs/development/` (development guides)

**Documentation Checklist:**

```bash
✅ Code changes implemented
✅ User testing completed successfully
✅ API testing verified (actual curl/HTTP requests)
✅ Relevant documentation files identified
✅ Documentation updated with:
   - What changed and why
   - How to use new/changed functionality
   - Examples and code snippets (from actual testing)
   - Configuration changes
   - Breaking changes (if any)
✅ Documentation committed to feature branch
✅ Ready to create pull request
```

**Example Documentation Update:**

```bash
# After user/API testing scan filtering feature, update docs:
vim blocksecops-docs/api/endpoints-reference.md
# Add severity parameter documentation with tested examples

vim TaskDocs-Apogee/blocksecops/03-phase-4-intelligence/scan-filtering-implementation.md
# Document implementation details and test results

# Commit documentation updates
git add blocksecops-docs/api/endpoints-reference.md
git add TaskDocs-Apogee/blocksecops/03-phase-4-intelligence/scan-filtering-implementation.md
git commit -m "docs: Update API and implementation docs for scan filtering"

# Push documentation updates with code changes
git push
```

**4. Create Pull Request:**

```bash
# Option 1: Using GitHub CLI
gh pr create \
  --title "feat: Add filtering by severity to scan endpoint" \
  --body "## Summary
- Adds severity filtering to scan list endpoint
- Supports multiple severity values
- Includes validation and tests

## Testing
- Unit tests added for filter logic
- Integration tests verify API behavior
- Manual testing with curl commands

## Breaking Changes
None - backwards compatible addition"

# Option 2: Via GitHub web interface
# Navigate to repository and click "Create Pull Request"
```

**5. Code Review and Merge:**

```bash
# CRITICAL: User (not Claude) reviews and merges PR
# - Review code changes in GitHub
# - Check CI/CD tests passed
# - Verify no merge conflicts
# - Click "Merge pull request" (as user, NOT as Claude)
# - Delete feature branch after merge
```

**6. Clean Up:**

```bash
# After PR is merged, delete local branch
git checkout main
git pull origin main
git branch -d feat/add-scan-filtering

# Remote branch is automatically deleted if "Delete branch" was clicked
```

### Branch Protection Rules

**MANDATORY settings for main branch:**

1. **Require pull request reviews** - At least 1 approval (in team environments)
2. **Require status checks** - Tests must pass before merge
3. **No direct commits to main** - All changes via PR
4. **Include administrators** - Even admins must follow workflow

**GitHub Settings Path:**
Repository → Settings → Branches → Branch protection rules → main

### Common Git Workflow Scenarios

**Scenario 1: Need to update feature branch with latest main:**

```bash
# Switch to your feature branch
git checkout feat/add-scan-filtering

# Fetch latest from remote
git fetch origin

# Rebase on top of latest main (preferred)
git rebase origin/main

# OR merge main into feature branch (alternative)
git merge origin/main

# Push updated feature branch
git push --force-with-lease  # If rebased
# or
git push  # If merged
```

**Scenario 2: Multiple commits in feature branch, want to squash:**

```bash
# Interactive rebase to squash commits
git rebase -i HEAD~3  # Last 3 commits

# In editor, change "pick" to "squash" for commits to combine
# Save and edit combined commit message

# Push squashed commits
git push --force-with-lease
```

**Scenario 3: Accidentally committed to main:**

```bash
# Create feature branch from current main state
git branch fix/accidental-commit

# Reset main to remote state (removes local commits)
git reset --hard origin/main

# Switch to feature branch (commits are preserved here)
git checkout fix/accidental-commit

# Push feature branch and create PR
git push -u origin fix/accidental-commit
gh pr create --title "fix: [description]" --body "[details]"
```

**Scenario 4: Need to make hotfix to production:**

```bash
# Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/critical-security-patch

# Make minimal changes to fix issue
vim src/security/auth.py
git add src/security/auth.py
git commit -m "hotfix: Patch critical security vulnerability

- Fix SQL injection in login endpoint
- Add input validation for email parameter
- Backport to stable branches

CRITICAL: Deploy immediately

Refs: SEC-001"

# Push and create PR marked as urgent
git push -u origin hotfix/critical-security-patch
gh pr create --title "HOTFIX: Critical security patch" --body "..."

# After review and merge, tag for deployment
git checkout main
git pull origin main
git tag -a v1.2.3 -m "Hotfix release v1.2.3 - Security patch"
git push origin v1.2.3
```

## Pull Request Requirements

**Every PR MUST include:**

1. **Clear title** describing the change (never mention Claude or Claude Code)
2. **Description** with:
   - What changed
   - Why it changed
   - How to test
   - Any breaking changes
3. **Updated documentation** (if applicable)
4. **Tests passing** (all CI/CD checks green)
5. **No merge conflicts** with main branch
6. **Commits merged by user account** (NEVER by Claude or automated tools)

**PR Title Format:**
```
<type>: <brief description>

Examples:
feat: Add severity filtering to scan endpoint
fix: Correct vulnerability status update logic
docs: Update API authentication guide
refactor: Simplify scan result processing
test: Add integration tests for scan workflow
```

**PR Description Template:**

```markdown
## Summary
Brief description of what this PR does (2-3 sentences).

## Changes
- Specific change 1
- Specific change 2
- Specific change 3

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests passing
- [ ] Manual testing completed
- [ ] Tested in local environment

## Breaking Changes
Yes/No - If yes, describe what breaks and migration path.

## Checklist
- [ ] Code follows project style guidelines
- [ ] Documentation updated
- [ ] Tests passing
- [ ] No merge conflicts
- [ ] Ready for review
```

**PR Review Checklist:**

Before merging any PR:
- [ ] All CI/CD checks passing (tests, linting, build)
- [ ] Code reviewed for quality and correctness
- [ ] No security vulnerabilities introduced
- [ ] Documentation updated if needed
- [ ] No merge conflicts with main
- [ ] Commit messages follow standards
- [ ] Breaking changes documented
- [ ] User (not Claude) performs the merge

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Documentation Standards](./documentation-standards.md) - Documentation requirements
- [Testing & Deployment](./testing-deployment.md) - Testing before deployment
