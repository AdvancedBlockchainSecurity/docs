# BlockSecOps Changelogs

**Purpose:** Centralized changelog directory for all BlockSecOps platform changes
**Last Updated:** February 4, 2026
**Status:** Active

---

## Overview

This directory contains comprehensive changelogs for the BlockSecOps platform. All significant changes, bug fixes, feature additions, and deployments are documented here.

### Organization

Changelogs are organized by component and maintained chronologically. Each changelog follows a consistent format with version numbers, dates, and categorized changes.

---

## Available Changelogs

### 0. Platform-Wide Bug Fixes v0.27/v0.40/v0.3 (`PLATFORM-V0.27-V0.40-V0.3-FIXES-2026-02-06.md`)

**Component:** blocksecops-api-service, blocksecops-dashboard, blocksecops-admin-portal
**Scope:** Info severity removal, pending-to-queued mapping, auto-apply filters, dark mode fixes, admin portal enhancements
**Date:** February 6, 2026

**Key Changes:**
- API v0.27.0: Removed info severity, pending→queued status mapping, audit log fixes, role management guards
- Dashboard v0.40.0: Light mode fixes, auto-apply filters, info severity removal from UI, queued status label
- Admin Portal v0.3.0: Pricing display fix, MFA verification modals, radar chart, retention banner
- Migration 034: Remap info/informational severity to low in vulnerability_patterns

**Use When:**
- Understanding info severity removal across the platform
- Debugging filter auto-apply behavior
- Reviewing dark/light mode fixes
- Understanding admin portal v0.3.0 changes

### 0. Admin Portal Dashboard Enhancement (`ADMIN-PORTAL-DASHBOARD-2026-02-04.md`)

**Component:** blocksecops-admin-portal
**Scope:** Comprehensive metrics dashboard for platform administrators
**Date:** February 4, 2026

**Key Changes:**
- Complete dashboard rewrite with 8 primary KPI cards
- Real-time system health monitoring
- Revenue & transaction analytics
- Vulnerability and deduplication statistics
- Intelligence database metrics
- Auto-refresh every 60 seconds
- Admin Portal 0.1.5

**Use When:**
- Understanding admin dashboard features
- Debugging admin portal metrics
- Adding new dashboard panels

### 0. Deduplication Metadata Audit Fixes (`DEDUPLICATION-METADATA-AUDIT-FIXES-2026-02-04.md`)

**Component:** blocksecops-api-service, blocksecops-tool-integration
**Scope:** Comprehensive audit fixes for deduplication and vulnerability metadata
**Date:** February 4, 2026

**Key Changes:**
- Migration 066: Added 4 indexes for classification columns
- Fixed FK cascade behavior (SET NULL instead of CASCADE)
- Semantic fingerprinting implementation
- SlitherParser scanner_id fallback fix
- API Service 0.25.4, Tool Integration 0.3.12

**Use When:**
- Understanding deduplication system fixes
- Debugging fingerprinting issues
- Reviewing database schema changes

### 0. Dashboard v0.38.1 Vulnerability Modal Link

**Component:** blocksecops-dashboard
**Scope:** Added "View Full Details" button in vulnerability modal
**Date:** February 4, 2026

**Key Changes:**
- New "View Full Details" button in scan results vulnerability modal
- Links to `/vulnerabilities/{id}` for full vulnerability detail page
- Dashboard 0.38.1

**Use When:**
- Understanding scan results UI changes
- Documenting vulnerability viewing workflow

### 0. Test Suite Maintenance (`TEST-SUITE-MAINTENANCE-2026-02-03.md`)

**Component:** blocksecops-api-service
**Scope:** Pattern ID standardization, ML dataclass updates, HTTP-based embedding tests
**Date:** February 3, 2026

**Key Changes:**
- Updated pattern IDs from `BVD-EVM-` to `BVD-SOLIDITY-` format
- Added `from_soft_deleted` and `multi_class_label` ML dataclass fields
- Rewrote SemanticDeduplicator tests for HTTP-based Intelligence Engine
- Added Move and Cairo smart contract test fixtures
- Fixed feature extractor line count for trailing newlines
- 616 tests passing, 19 skipped

**Use When:**
- Understanding test suite changes
- Debugging test failures related to pattern IDs
- Understanding ML dataclass field requirements

### 0. SolidityDefend Scanner Wrapper 0.5.0 (`SOLIDITYDEFEND-0.5.0-UPGRADE-2026-01-31.md`)

**Component:** blocksecops-tool-integration
**Scope:** Scanner image upgrade, playbook creation
**Date:** January 31, 2026

**Key Changes:**
- Scanner wrapper image 0.4.0 → 0.5.0 (tool version 1.10.3)
- 333 detectors, clean slate approach with old findings deleted
- Created reusable playbook: `docs/playbooks/upgrade-scanner-image.md`
- Test scan verified: 34 findings (12 critical, 15 high, 4 medium, 3 low)
- Bug fix: API service `last_scan_at` column reference removed

**Use When:**
- Understanding scanner wrapper upgrade process
- Following scanner upgrade playbook
- Reviewing SolidityDefend capabilities

### 0. Dashboard v0.29.0 UI Updates (`DASHBOARD-V0.29.0-UI-UPDATES-2026-01-13.md`)

**Component:** blocksecops-dashboard
**Scope:** Quality Gates integration, search improvements, filter layout fix
**Date:** January 13, 2026

**Key Changes:**
- QualityGatePanel integrated into ProjectDetail page
- Contracts page search (filter by name/address)
- `/search` renamed to `/advanced-search`
- Contract links in Advanced Search results
- Fixed filter overflow in Advanced Search page

**Use When:**
- Understanding v0.29.0 dashboard changes
- Debugging Advanced Search filter layout
- Understanding Quality Gates UI integration

### 0. API Endpoints Changelog (`API-ENDPOINTS-CHANGELOG.md`)

**Component:** blocksecops-api-service
**Scope:** Complete API version history (v1.0.0 - v1.3.0)
**Date:** October 2025 - December 2025

**Key Changes:**
- Consolidated from blocksecops-docs/api/endpoints-reference.md
- All API versions from v1.0.0 to v1.3.0
- Phase 3.4, 3.1b, 4.5 feature additions
- Database schema updates and tier access control

**Use When:**
- Looking up when an endpoint was added
- Understanding API version history
- Reviewing database migration history

### 0. Dark Mode & Global Search (`DARK-MODE-GLOBAL-SEARCH-2025-12-26.md`)

**Component:** blocksecops-api-service, blocksecops-dashboard
**Scope:** UX enhancements - theme switching and command palette search
**Date:** December 26, 2025

**Key Changes:**
- Dark mode toggle (light/dark/system) with localStorage persistence
- Command Palette (Cmd+K / Ctrl+K) for quick navigation
- `GET /search/quick` API endpoint with source code search
- Line number + code snippet display in search results
- Dashboard v0.14.0, API Service v0.6.0

**Use When:**
- Understanding theme system implementation
- Debugging search functionality
- Adding new searchable entity types
- Customizing dark mode colors

### 0. Vulnerability Categorization Fix (`VULNERABILITY-CATEGORIZATION-FIX-2025-12-23.md`)

**Component:** blocksecops-api-service
**Scope:** Vulnerability categorization, scan statistics, pattern lookup
**Date:** December 23, 2025

**Key Changes:**
- Fixed SolidityDefend findings showing as "uncategorized" (486+ rows)
- Implemented `_lookup_pattern_category()` to query pattern_tool_mappings table
- Fixed Aderyn scanner_id values (60+ rows)
- Fixed scan statistics to match actual vulnerability counts (16 scans)
- Added 4 missing SolidityDefend pattern mappings
- Built api-service:0.5.1

**Use When:**
- Understanding vulnerability categorization system
- Debugging category display issues
- Adding new scanner pattern mappings
- Fixing scan statistics discrepancies

### 0. Scanner Pattern Coverage Audit (`SCANNER-PATTERN-AUDIT-2025-12-20.md`)

**Component:** blocksecops-api-service, blocksecops-orchestration
**Scope:** Data integrity fixes for vulnerability patterns and scanner registry
**Date:** December 20, 2025

**Key Changes:**
- Fixed 5 duplicate pattern IDs (DAT-004→DAT-006, L2-001→L2-002, ORA-003→ORA-009, ORA-004 merged, VAL-001→VAL-002)
- Added MythrilExecutor to scanner registry (was missing, 4 pattern mappings orphaned)
- Fixed Vyper scanner ID mismatch (99 pattern mappings affected)
- Updated verification script with correct field names and counts
- Pattern count: 398→397 (1 merged), Mappings: 638, Scanners: 16→17

**Use When:**
- Understanding pattern database fixes
- Debugging scanner-pattern mismatches
- Verifying scanner coverage after updates
- Running scanner coverage verification script

### 1. Phase 3.5 Parsers - Vyper & Solana (`PHASE-3.5-PARSERS-2025-12-20.md`)

**Component:** blocksecops-tool-integration
**Scope:** Scanner output parsers for Vyper and Solana/Rust scanners
**Date:** December 20, 2025

**Key Changes:**
- Added MoccasinParser for Vyper fuzzing output
- Added SolAzyParser, Sec3XRayParser, TridentParser, CargoFuzzSolanaParser for Solana
- Added GenericJsonParser as fallback for unknown scanners
- 27 unit tests passing, SlitherParser validated with real output

**Use When:**
- Understanding Phase 3.5 parser implementation
- Adding new scanner output parsers
- Debugging parser output normalization
- Reviewing vulnerability severity mapping

### 1. Platform Validation & Vyper/Moccasin Integration (`PLATFORM-VALIDATION-VYPER-MOCCASIN-2025-12-15.md`)

**Component:** blocksecops-orchestration, blocksecops-notification
**Scope:** Vyper/Moccasin scanner integration, WebSocket fix, platform validation
**Date:** December 15, 2025

**Key Changes:**
- Vyper and Moccasin scanners integrated
- Solana scanners enabled via Docker-based execution (16/16 scanners now available)
- WebSocket 403 error fixed (notification service routing)
- E2E scan workflow validated
- Scanner documentation created (Vyper, Moccasin READMEs)

**Use When:**
- Understanding Vyper scanner integration
- Debugging WebSocket issues
- Reviewing platform validation results
- Setting up scanner port-forwards

### 1. Dashboard Authentication (`dashboard-authentication.md`)

**Component:** blocksecops-dashboard
**Scope:** Authentication system changes and optimizations
**Versions Covered:** v1.0.0 - v1.1.1
**Date Range:** November 2025

**Key Changes:**
- v1.1.1 (Nov 21, 2025): React Hooks violation fix
- v1.1.0 (Nov 20, 2025): Production-ready authentication optimization
- v1.0.0 (Nov 2025): Supabase Auth migration

**Use When:**
- Understanding dashboard authentication evolution
- Debugging authentication-related issues
- Reviewing performance optimizations
- Learning from React Hooks fix

### 2. API Service JWT ES256 (`api-service-jwt-es256.md`)

**Component:** blocksecops-api-service
**Scope:** JWT verification and Supabase authentication integration
**Version:** 0.3.1
**Date:** November 19, 2025

**Key Changes:**
- Fixed JWT verification with ES256 algorithm support
- Updated JWKS endpoint to RFC 8414 compliant path
- Added Supabase credentials to Kubernetes configmap
- Removed component-specific CHANGELOG.md per platform standards

**Use When:**
- Understanding JWT verification implementation
- Debugging authentication 401 errors
- Reviewing ES256 vs RS256 differences
- Setting up Supabase integration

### 3. Orchestration Deployment (`orchestration-deployment.md`)

**Component:** blocksecops-orchestration
**Scope:** Deployment history and service updates
**Versions Covered:** 0.7.12 - 0.7.14, Intelligence Integration Phase 2
**Date Range:** October 2025

**Key Changes:**
- Intelligence Integration Phase 2 (Semgrep & Solhint)
- Parser fixes for enrichment service (v0.7.14)
- Tree-sitter API compatibility (v0.7.13)
- Vulnerability pattern library expansion (30 → 69 patterns)

**Use When:**
- Tracking orchestration service deployments
- Understanding intelligence integration progress
- Reviewing parser updates
- Planning rollback procedures

---

## Changelog Standards

### Format Requirements

All changelogs must include:

1. **Version Information**
   - Version number (semantic versioning)
   - Release date
   - Status (Complete, In Progress, Deprecated)

2. **Change Categories**
   - ✅ Added: New features
   - 🔧 Changed: Modifications to existing features
   - 🐛 Fixed: Bug fixes
   - ❌ Removed: Deprecated features
   - 🔒 Security: Security-related changes
   - ⚡ Performance: Performance improvements

3. **Technical Details**
   - Files modified with line numbers
   - Code examples for significant changes
   - Testing verification steps
   - Deployment instructions

4. **Impact Assessment**
   - Severity level (Critical, High, Medium, Low)
   - User impact description
   - Breaking changes highlighted
   - Migration notes if applicable

5. **References**
   - Related PRs and issues
   - Related documentation
   - External references

### Template Structure

```markdown
# Component Changelog - Title

## Version X.Y.Z - Feature Name - Date

**Date:** YYYY-MM-DD
**Component:** component-name
**Type:** Feature/Bug Fix/Performance/Security
**Priority:** Critical/High/Medium/Low
**Status:** ✅ Complete/⏳ In Progress

### Summary
Brief description of changes

### Issues Resolved
List of problems fixed

### Added ✅
- New features added

### Changed 🔧
- Modifications made

### Fixed 🐛
- Bugs fixed

### Removed ❌
- Deprecated features

### Code Changes
**Files Modified:**
- path/to/file.ext (lines X-Y)

**Key Changes:**
```code examples```

### Testing
- Test scenarios
- Verification steps

### Impact
- User impact
- Performance metrics
- Breaking changes

### Related Documentation
- Links to related docs
```

---

## Changelog Location Rules

### Platform-Wide Changelogs (This Directory)

**Location:** `/Users/pwner/Git/ABS/docs/changelogs/`

**Contents:**
- Cross-component changes
- Major platform updates
- Authentication/authorization changes
- Database migrations affecting multiple services
- Deployment procedures
- Integration changes

**Examples:**
- Dashboard authentication changes
- API service authentication changes
- Multi-service deployments
- Platform-wide security updates

### Component-Specific Changelogs (Component Directories)

**Location:** `<component-root>/CHANGELOG.md`

**Contents:**
- Component-internal changes
- Library version updates
- Minor bug fixes
- Component-specific features
- Dependency updates

**Examples:**
- `blocksecops-orchestration/CHANGELOG.md`
- `blocksecops-frontend/CHANGELOG.md`
- `SolidityDefend/CHANGELOG.md`

**Note:** Per platform standards, consider whether component changelogs should exist or if all changes should be tracked in this centralized location.

### Task-Specific Changelogs (TaskDocs)

**Location:** `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/phases/`

**Contents:**
- Temporary task tracking
- Work-in-progress changes
- Implementation details during development
- Phase-specific progress

**Migration Rule:** Once tasks are complete and deployed, migrate relevant changelog entries to this centralized directory.

---

## Changelog Naming Conventions

### File Naming

**Format:** `<component>-<scope>-<optional-date>.md`

**Examples:**
- `dashboard-authentication.md` - Ongoing changelog for dashboard auth
- `api-service-jwt-es256.md` - Specific feature implementation
- `orchestration-deployment.md` - Deployment tracking
- `database-migrations-2025-q4.md` - Quarterly migration log

**Guidelines:**
- Use lowercase with hyphens
- Be descriptive but concise
- Include date only for historical/archived changelogs
- Avoid version numbers in filename (versions go inside the file)

### Section Naming

Within changelog files:
- `## Version X.Y.Z - Feature Name - Date`
- Use semantic versioning (MAJOR.MINOR.PATCH)
- Include descriptive feature name
- Always include full date (YYYY-MM-DD)

---

## Changelog Workflow

### Creating a New Changelog

1. **Determine Scope**
   - Is this platform-wide or component-specific?
   - Does it affect multiple services?
   - Is it significant enough to warrant documentation?

2. **Choose Location**
   - Platform-wide: `/docs/changelogs/`
   - Component-specific: `<component>/CHANGELOG.md`
   - Task-specific: `TaskDocs-BlockSecOps/phases/`

3. **Use Template**
   - Copy template structure from this README
   - Fill in all required sections
   - Include code examples for significant changes

4. **Link Related Docs**
   - Update main README if applicable
   - Link to technical documentation
   - Reference related changelogs

### Updating Existing Changelog

1. **Add New Entry at Top**
   - Most recent changes should appear first
   - Keep version history section at bottom

2. **Update Summary**
   - Update "Last Updated" date
   - Increment version numbers
   - Update status indicators

3. **Maintain Consistency**
   - Follow existing format
   - Use same change categories
   - Keep similar level of detail

### Archiving Old Changelogs

When a changelog becomes too large or covers a completed phase:

1. **Create Archive**
   - Move to `changelogs/archive/YYYY/`
   - Rename with full date range: `component-YYYY-MM-DD-to-YYYY-MM-DD.md`

2. **Update Index**
   - Add entry to "Archived Changelogs" section below
   - Keep link active for reference

3. **Start New Changelog**
   - Create fresh changelog for new period
   - Link to archived version in preamble

---

## Quick Reference

### Finding the Right Changelog

**I need to understand authentication changes:**
→ `dashboard-authentication.md` for frontend
→ `api-service-jwt-es256.md` for backend

**I need deployment history:**
→ `orchestration-deployment.md`

**I need to see what changed in a specific version:**
→ Search all changelogs for version number

**I need to understand a bug fix:**
→ Check `dashboard-authentication.md` or component-specific changelog
→ Also check `/docs/fixes/` directory for detailed fix documentation

### Changelog Search Commands

```bash
# Find all changelogs
ls /Users/pwner/Git/ABS/docs/changelogs/

# Search for specific version
grep -r "v1.1.1" /Users/pwner/Git/ABS/docs/changelogs/

# Find recent changes (last 7 days)
find /Users/pwner/Git/ABS/docs/changelogs -type f -mtime -7

# Search for specific feature
grep -r "React Hooks" /Users/pwner/Git/ABS/docs/changelogs/
```

---

## Related Documentation

### Documentation Hierarchy

```
/Users/pwner/Git/ABS/docs/
├── changelogs/               ← You are here
│   ├── README.md            ← This file
│   ├── dashboard-authentication.md
│   ├── api-service-jwt-es256.md
│   └── orchestration-deployment.md
├── fixes/                   ← Detailed fix documentation
│   ├── login-react-hooks-violation-fix-2025-11-21.md
│   └── ...
├── database/                ← Database-specific docs
│   ├── migrations/
│   └── SCHEMA.md
└── standards/               ← Platform standards

/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/
└── phases/                  ← Task-specific changelogs (work in progress)

/Users/pwner/Git/ABS/blocksecops-docs/
├── architecture/            ← System architecture docs
├── deployment/              ← Deployment guides (includes old changelog)
└── development/             ← Development guides
```

### Documentation Cross-References

**Changelog** → **Fix Documentation**
- Changelogs provide high-level overview
- Fix docs provide detailed analysis
- Always cross-reference between them

**Example:**
- `dashboard-authentication.md` (v1.1.1 entry)
- Links to → `/docs/fixes/login-react-hooks-violation-fix-2025-11-21.md`

**Changelog** → **Technical Documentation**
- Changelogs track what changed
- Technical docs explain how it works
- Link to architecture docs for context

**Example:**
- `api-service-jwt-es256.md` (JWT verification)
- Links to → `/blocksecops-docs/architecture/authentication-system.md`

---

## Archived Changelogs

### Q4 2025 Archives

*No archived changelogs yet. Archives will appear here when created.*

### Archive Structure

When creating archives:
```
changelogs/
├── README.md (this file)
├── archive/
│   ├── 2025/
│   │   ├── Q4/
│   │   │   └── [archived-changelog].md
│   │   └── Q3/
│   └── 2024/
└── [active-changelogs].md
```

---

## Maintenance

### Changelog Maintenance Schedule

**Weekly:**
- Review TaskDocs for completed changes
- Move stable changes to appropriate changelogs
- Update version numbers

**Monthly:**
- Review changelog sizes
- Consider archiving large changelogs
- Update this README with new entries
- Verify all links are working

**Quarterly:**
- Archive completed phase changelogs
- Create quarterly summary
- Review and update standards

### Changelog Quality Checklist

Before committing changelog updates:

- [ ] All sections filled out (no placeholders)
- [ ] Version number follows semantic versioning
- [ ] Date is accurate (YYYY-MM-DD format)
- [ ] Status indicator is correct (✅/⏳/❌)
- [ ] Change categories used consistently
- [ ] Code examples are accurate and tested
- [ ] Testing verification steps included
- [ ] Impact assessment completed
- [ ] Related documentation linked
- [ ] File modified lists include line numbers
- [ ] Breaking changes clearly marked
- [ ] Migration notes provided if needed

---

## Contributing to Changelogs

### Who Should Update Changelogs?

**Developers:**
- Add entries for features they implement
- Document bug fixes
- Record breaking changes

**DevOps:**
- Document deployments
- Record infrastructure changes
- Track version updates

**Documentation Team:**
- Maintain changelog format
- Ensure consistency
- Archive old changelogs

### How to Contribute

1. **Before Making Changes:**
   - Read this README
   - Review existing changelog format
   - Determine correct changelog file

2. **Writing the Entry:**
   - Use the template structure
   - Be clear and concise
   - Include all required information
   - Add code examples for clarity

3. **Submitting Changes:**
   - Update appropriate changelog(s)
   - Update "Last Updated" date
   - Link to related documentation
   - Submit PR with changelog in same commit as code changes

4. **Review Process:**
   - Self-review using quality checklist
   - Verify all links work
   - Test code examples
   - Request peer review

---

## FAQ

### Q: Should every change have a changelog entry?

**A:** Not necessarily. Use these guidelines:
- ✅ Yes: User-facing changes, bug fixes, new features, breaking changes
- ✅ Yes: Performance improvements, security updates, API changes
- ⚠️ Maybe: Internal refactoring, minor optimizations, dependency updates
- ❌ No: Typo fixes, comment updates, non-functional changes

### Q: Where do I document a change that affects multiple components?

**A:** Create an entry in the most relevant changelog in `/docs/changelogs/`. If it's truly cross-cutting, consider creating a new dedicated changelog file.

### Q: How detailed should changelog entries be?

**A:** Include enough detail that someone unfamiliar with the change can understand:
- What changed
- Why it changed
- How to use the new feature or adapt to the change
- What was fixed or improved

### Q: Should I include code examples?

**A:** Yes, for:
- API changes
- Breaking changes
- Complex features
- Bug fixes that might reoccur

### Q: How do I handle breaking changes?

**A:**
1. Mark clearly with 🔴 or "BREAKING CHANGE" label
2. Explain what breaks
3. Provide migration guide
4. Include before/after code examples
5. Link to migration documentation

### Q: What's the difference between a changelog and fix documentation?

**A:**
- **Changelog**: High-level overview, what changed, brief why
- **Fix Documentation**: Deep dive, root cause analysis, prevention measures

Always create both for significant bug fixes.

---

## Support

### Questions or Issues?

- **Changelog Format Questions**: Review this README
- **Where to Document**: See "Changelog Location Rules" section
- **Missing Information**: Check related documentation in `/docs/` or `/blocksecops-docs/`
- **Unclear Standards**: Refer to `/docs/standards/`

### Changelog Updates Needed?

If you notice:
- Missing changelog entry
- Incorrect information
- Broken links
- Outdated content

Create an issue or submit a PR with corrections.

---

## Version History

### This README

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2025-11-21 | Initial creation of centralized changelog directory |

---

**Maintained By:** BlockSecOps Documentation Team
**Location:** `/Users/pwner/Git/ABS/docs/changelogs/README.md`
**Last Updated:** December 20, 2025
**Status:** ✅ Active
