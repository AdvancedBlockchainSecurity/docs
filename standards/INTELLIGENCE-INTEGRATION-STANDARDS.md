# Intelligence Integration Standards

**Version**: 1.0.0
**Created**: October 29, 2025
**Last Updated**: October 29, 2025
**Status**: Active - MANDATORY for all intelligence integration work
**Compliance Level**: CRITICAL

---

## Table of Contents

1. [Overview](#overview)
2. [Integration Workflow](#integration-workflow)
3. [Pattern Creation Standards](#pattern-creation-standards)
4. [Mapping Creation Standards](#mapping-creation-standards)
5. [Database Migration Requirements](#database-migration-requirements)
6. [Testing Requirements](#testing-requirements)
7. [Documentation Requirements](#documentation-requirements)
8. [Production Deployment Checklist](#production-deployment-checklist)
9. [Quality Gates](#quality-gates)
10. [Rollback Procedures](#rollback-procedures)
11. [Templates and Examples](#templates-and-examples)
12. [Common Pitfalls](#common-pitfalls)
13. [Compliance Checklist](#compliance-checklist)

---

## Overview

### Purpose

This document defines mandatory standards for integrating security scanners, vulnerability patterns, and detector mappings into the Apogee Intelligence Platform. Following these standards ensures:

- **Production Readiness**: All integrations are deployment-ready
- **Data Integrity**: Database consistency and recoverability
- **Quality Assurance**: Comprehensive testing at every stage
- **Documentation**: Complete audit trail and knowledge transfer
- **Rollback Safety**: Ability to revert changes without data loss

### Scope

These standards apply to:
- Adding new security scanners to the platform
- Creating vulnerability patterns
- Mapping scanner detectors to patterns
- Database schema changes
- Intelligence service updates

### Compliance

**MANDATORY**: All intelligence integration work MUST follow these standards. Non-compliant integrations will be rejected during code review.

---

## Integration Workflow

### Phase-Based Approach

All intelligence integrations MUST follow this 8-phase workflow:

```
Phase 1: Analysis & Planning (2-4 hours)
    ↓
Phase 2: Pattern Creation (4-8 hours)
    ↓
Phase 3: Mapping Creation (2-4 hours)
    ↓
Phase 4: Database Migration (1-2 hours)
    ↓
Phase 5: Integration Testing (2-3 hours)
    ↓
Phase 6: Documentation (2-3 hours)
    ↓
Phase 7: Code Review & Approval (1-2 hours)
    ↓
Phase 8: Production Deployment (1-2 hours)
```

**Total Timeline**: 15-28 hours per scanner

### Phase 1: Analysis & Planning

**Objective**: Understand scanner capabilities and plan integration approach

**Mandatory Tasks**:
1. Document scanner details:
   - Total detector count
   - Severity breakdown (critical/high/medium/low)
   - Output format analysis
   - Example output collection

2. Pattern analysis:
   - Identify detectors mapping to existing patterns
   - Identify detectors requiring new patterns
   - Document unmapped detectors

3. Create integration plan document:
   - Timeline estimate
   - Pattern creation list
   - Mapping strategy
   - Risk assessment

**Deliverables**:
- [ ] Scanner analysis document
- [ ] Pattern gap analysis
- [ ] Integration plan with timeline
- [ ] Risk assessment

**Quality Gate**: Plan must be reviewed and approved before proceeding

---

### Phase 2: Pattern Creation

**Objective**: Create high-quality vulnerability patterns for unmapped detectors

**Mandatory Standards** (see [Pattern Creation Standards](#pattern-creation-standards)):

1. **BVD Pattern ID Format**:
   - Format: `BVD-XXX-###`
   - Category codes: 3 uppercase letters (e.g., REE, ACC, INT)
   - Sequential numbering within category (001-999)

2. **Required Fields**:
   ```json
   {
     "id": "BVD-XXX-###",           // REQUIRED
     "name": "Pattern Name",         // REQUIRED
     "category": "category-name",    // REQUIRED
     "severity": "high",             // REQUIRED
     "description": "...",           // REQUIRED
     "swc_id": "SWC-###",           // REQUIRED for Solidity
     "cwe_id": "CWE-###",           // REQUIRED
     "owasp_category": "...",       // REQUIRED
     "remediation": "...",          // REQUIRED
     "fix_examples": [...],         // REQUIRED (min 2)
     "references": [...],           // REQUIRED (min 2)
     "detection_methods": [...],    // REQUIRED
     "false_positive_rate": 0.0,   // REQUIRED
     "affected_languages": [...],   // REQUIRED
     "semantic_description": "...", // REQUIRED
     "keywords": [...]              // REQUIRED (min 3)
   }
   ```

3. **Quality Requirements**:
   - Clear, concise descriptions (< 200 chars)
   - At least 2 fix examples
   - At least 2 authoritative references
   - Keywords for semantic matching
   - SWC/CWE mappings from official registries

**Deliverables**:
- [ ] Pattern definitions in JSON format
- [ ] Pattern validation passed
- [ ] Peer review completed

**Quality Gate**: All patterns must pass validation schema before proceeding

---

### Phase 3: Mapping Creation

**Objective**: Create accurate detector-to-pattern mappings

**Mandatory Standards** (see [Mapping Creation Standards](#mapping-creation-standards)):

1. **Mapping Format**:
   ```json
   {
     "pattern_id": "BVD-XXX-###",
     "scanner_id": "scanner-name",
     "detector_id": "detector-name",
     "match_type": "exact"
   }
   ```

2. **Match Types**:
   - `exact`: 1:1 mapping (preferred, >90% accuracy)
   - `fuzzy`: Close match (80-90% accuracy)
   - `semantic`: ML-based match (<80% accuracy)

3. **Mapping Quality**:
   - Prefer exact matches
   - Document reasoning for fuzzy/semantic matches
   - Test each mapping with sample findings

**Deliverables**:
- [ ] Mapping definitions in JSON format
- [ ] Match quality documentation
- [ ] Sample findings for validation

**Quality Gate**: All mappings must have documented match quality rationale

---

### Phase 4: Database Migration

**Objective**: Create production-ready Alembic migration

**⚠️ CRITICAL**: This phase was missed in early integrations. It is MANDATORY.

**Mandatory Requirements**:

1. **Alembic Migration File**:
   - Naming: `YYYYMMDD_HHMM-###_descriptive_name.py`
   - Example: `20251029_1600-011_aderyn_100_percent_integration.py`

2. **Migration Properties**:
   - **Idempotent**: Must use `ON CONFLICT DO NOTHING`
   - **Rollback**: Must include complete `downgrade()` function
   - **Tested**: Must be tested in local environment
   - **Documented**: Must include migration notes

3. **Migration Template**:
   ```python
   """scanner integration vX.Y

   Revision ID: ###
   Revises: previous
   Create Date: YYYY-MM-DD HH:MM:SS

   Intelligence Platform vX.Y: Scanner Integration
   - Add N new vulnerability patterns
   - Add M new detector-to-pattern mappings
   """

   def upgrade() -> None:
       # Insert patterns with ON CONFLICT DO NOTHING
       # Insert mappings with ON CONFLICT DO NOTHING
       pass

   def downgrade() -> None:
       # Remove mappings
       # Remove patterns
       pass
   ```

4. **Pre-Migration Checklist**:
   - [ ] Database backup created
   - [ ] Backup verified (can be read)
   - [ ] Migration tested locally
   - [ ] Rollback tested locally
   - [ ] Migration is idempotent

**Deliverables**:
- [ ] Alembic migration file created
- [ ] Migration tested successfully
- [ ] Rollback tested successfully
- [ ] Database backup created

**Quality Gate**: Migration must pass local testing before code review

---

### Phase 5: Integration Testing

**Objective**: Validate integration works end-to-end

**Mandatory Test Suites**:

1. **Pattern Database Tests**:
   ```python
   # tests/integration/test_<scanner>_integration_complete.py
   - test_100_percent_coverage()
   - test_version_updated()
   - test_total_patterns_count()
   - test_all_mappings_exist()
   - test_pattern_attributes()
   - test_no_duplicate_mappings()
   ```

2. **Pattern Matching Tests**:
   ```python
   # tests/integration/test_<scanner>_pattern_matching.py
   - test_<detector>_pattern_matching()  # For each detector
   - test_all_detectors_have_mappings()
   - test_pattern_lookup_works()
   ```

3. **Cross-Tool Deduplication Tests**:
   ```python
   # tests/integration/test_<scanner>_pattern_matching.py
   - test_<vulnerability>_deduplication_across_tools()
   - test_fingerprint_generation()
   - test_deduplication_group_formation()
   ```

4. **Sample Vulnerable Contracts**:
   - Create test contracts with intentional vulnerabilities
   - Test each new pattern with actual code
   - Validate findings are enriched correctly

**Test Coverage Requirements**:
- Minimum 90% test coverage for new code
- All new patterns must have test cases
- All new mappings must be validated

**Deliverables**:
- [ ] Integration test suite created
- [ ] All tests passing (100%)
- [ ] Sample contracts created
- [ ] Test coverage ≥90%

**Quality Gate**: All tests must pass before documentation phase

---

### Phase 6: Documentation

**Objective**: Create comprehensive documentation for integration

**Mandatory Documentation**:

1. **Integration Summary** (`implementation-summaries/<SCANNER>-INTELLIGENCE-INTEGRATION-COMPLETE.md`):
   - Executive summary with metrics
   - Pattern breakdown by category
   - Mapping quality distribution
   - Testing evidence
   - Business impact analysis
   - Lessons learned

2. **Release Notes** (`RELEASE-NOTES-vX.Y.md`):
   - Version number and date
   - Summary of changes
   - New patterns (detailed)
   - New mappings
   - Breaking changes (if any)
   - Migration instructions
   - Rollback instructions
   - Performance impact

3. **JIRA Updates**:
   - Update story status to "Done"
   - Add completion percentage
   - Link to PRs and documentation
   - Attach testing evidence
   - Update epic progress

4. **Tracking Documents**:
   - Update `INTELLIGENCE-INTEGRATION-TASKS.md`
   - Update `SCANNER-DETECTOR-TRACKING.md`
   - Update `ADERYN-INTEGRATION-IMPLEMENTATION-PLAN.md` (if applicable)

**Documentation Quality**:
- Clear, concise language
- Include code examples
- Link to related resources
- Keep CHANGELOG updated

**Deliverables**:
- [ ] Integration summary created
- [ ] Release notes created
- [ ] JIRA tickets updated
- [ ] Tracking documents updated
- [ ] README updated (if needed)

**Quality Gate**: Documentation must be reviewed for clarity and completeness

---

### Phase 7: Code Review & Approval

**Objective**: Peer review ensures quality and catches issues

**Review Checklist**:

1. **Code Quality**:
   - [ ] Follows project style guidelines
   - [ ] No hardcoded values
   - [ ] Proper error handling
   - [ ] Efficient algorithms

2. **Database Migration**:
   - [ ] Migration is idempotent
   - [ ] Rollback function complete
   - [ ] Tested in local environment
   - [ ] No data loss risk

3. **Testing**:
   - [ ] All tests passing
   - [ ] Test coverage ≥90%
   - [ ] Integration tests comprehensive
   - [ ] Sample contracts included

4. **Documentation**:
   - [ ] Release notes complete
   - [ ] Migration instructions clear
   - [ ] Rollback procedure documented
   - [ ] JIRA updated

5. **Production Readiness**:
   - [ ] Database backup plan
   - [ ] Rollback strategy documented
   - [ ] Performance impact assessed
   - [ ] Security reviewed

**Review Process**:
1. Create PR with comprehensive description
2. Request review from 2+ team members
3. Address all review comments
4. Obtain approval from tech lead
5. Merge only after all checks pass

**Deliverables**:
- [ ] PR created with detailed description
- [ ] Code review completed
- [ ] All comments addressed
- [ ] Approval obtained

**Quality Gate**: Must have 2+ approvals before merging

---

### Phase 8: Production Deployment

**Objective**: Deploy to production safely with zero downtime

**Pre-Deployment Checklist**:
- [ ] All PRs merged
- [ ] Production database backup created
- [ ] Backup verified (can be restored)
- [ ] Migration tested in staging (if available)
- [ ] Team notified of deployment window
- [ ] Rollback plan documented and ready
- [ ] Monitoring alerts configured

**Deployment Steps**:

1. **Create Production Backup**:
   ```bash
   # MANDATORY: Always backup before deployment
   kubectl exec -it deployment/postgresql -n production -- \
     pg_dump -U postgres -d solidity_security | \
     gzip > backups/production_pre_vX.Y_$(date +%Y%m%d_%H%M%S).sql.gz
   ```

2. **Build and Push Docker Image**:
   ```bash
   docker build --no-cache -t blocksecops/api-service:X.Y.Z .
   docker push blocksecops/api-service:X.Y.Z
   ```

3. **Deploy to Kubernetes**:
   ```bash
   kubectl set image deployment/api-service \
     api-service=blocksecops/api-service:X.Y.Z \
     -n production
   ```

4. **Run Database Migration**:
   ```bash
   kubectl exec -it deployment/api-service -n production -- \
     alembic upgrade head
   ```

5. **Verify Deployment**:
   ```bash
   # Health check
   curl https://api.0xapogee.com/api/v1/health/ready

   # Pattern count
   kubectl exec -it deployment/postgresql -n production -- \
     psql -U postgres -d solidity_security \
     -c "SELECT COUNT(*) FROM vulnerability_patterns;"

   # Mapping count
   kubectl exec -it deployment/postgresql -n production -- \
     psql -U postgres -d solidity_security \
     -c "SELECT COUNT(*) FROM pattern_tool_mappings WHERE scanner_id='<scanner>';"
   ```

6. **Monitor for Issues**:
   ```bash
   # Watch logs
   kubectl logs -f deployment/api-service -n production

   # Check for errors
   kubectl logs deployment/api-service -n production --since=10m | grep -i error
   ```

**Post-Deployment**:
- [ ] Verify health checks passing
- [ ] Verify pattern count correct
- [ ] Verify mappings inserted
- [ ] Monitor logs for 1 hour
- [ ] Test scanner in production
- [ ] Notify team of successful deployment

**Deliverables**:
- [ ] Production backup created
- [ ] Deployment successful
- [ ] Health checks passing
- [ ] Monitoring confirms stability

**Quality Gate**: System must be stable for 1 hour before considering deployment complete

---

## Pattern Creation Standards

### BVD Pattern ID Format

**Format**: `BVD-XXX-###`

**Components**:
- `BVD`: Apogee Vulnerability Database prefix (fixed)
- `XXX`: Three-letter category code (uppercase)
- `###`: Sequential number within category (001-999)

**Category Codes**:

| Code | Category | Description | Example IDs |
|------|----------|-------------|-------------|
| REE | reentrancy | Reentrancy vulnerabilities | BVD-SOLIDITY-REE-001, BVD-SOLIDITY-REE-002 |
| ACC | access-control | Access control issues | BVD-SOLIDITY-ACC-001, BVD-SOLIDITY-ACC-006 |
| INT | integer-overflow | Integer overflow/underflow | BVD-SOLIDITY-INT-001, BVD-SOLIDITY-INT-002 |
| UNC | unchecked-calls | Unchecked external calls | BVD-SOLIDITY-UNC-001, BVD-SOLIDITY-UNC-002 |
| TIM | timestamp | Timestamp manipulation | BVD-SOLIDITY-TIM-001, BVD-SOLIDITY-TIM-002 |
| RAN | randomness | Weak randomness | BVD-SOLIDITY-RAN-001 |
| DEL | delegatecall | Delegatecall issues | BVD-SOLIDITY-DEL-001, BVD-SOLIDITY-DEL-002 |
| FRO | front-running | Front-running vulnerabilities | BVD-SOLIDITY-FRO-001, BVD-SOLIDITY-FRO-002 |
| DOS | denial-of-service | DoS vulnerabilities | BVD-SOLIDITY-DOS-001, BVD-SOLIDITY-DOS-003 |
| GAS | gas-optimization | Gas optimization issues | BVD-SOLIDITY-GAS-001, BVD-SOLIDITY-GAS-010 |
| COD | code-quality | Code quality issues | BVD-SOLIDITY-COD-001, BVD-SOLIDITY-COD-004 |
| DEP | deprecated | Deprecated patterns | BVD-SOLIDITY-DEP-001, BVD-SOLIDITY-DEP-002 |
| ENC | encoding | Encoding issues | BVD-SOLIDITY-ENC-001 |
| BAL | validation | Balance/validation checks | BVD-SOLIDITY-BAL-001 |
| LOC | locked-ether | Locked ether issues | BVD-SOLIDITY-LOC-001 |
| COL | collision | Collision vulnerabilities | BVD-SOLIDITY-COL-001 |
| ERC | interface | ERC standard compliance | BVD-SOLIDITY-ERC-001, BVD-SOLIDITY-ERC-002 |
| MUL | multicall | Multicall issues | BVD-SOLIDITY-MUL-001 |
| SEL | selfdestruct | Selfdestruct issues | BVD-SOLIDITY-SEL-001 |
| LOG | logic | Logic errors | BVD-SOLIDITY-LOG-001, BVD-SOLIDITY-LOG-010 |

**Adding New Categories**:
1. Check if existing category fits
2. If not, propose new 3-letter code
3. Update this table
4. Document in CHANGELOG

### Pattern Field Requirements

#### Required Fields

**1. id** (string, 20 chars max)
- Format: `BVD-XXX-###`
- Must be unique
- Never reuse deleted IDs

**2. name** (string, 200 chars max)
- Clear, descriptive name
- Use title case
- Examples: "Reentrancy Attack", "Integer Overflow"

**3. category** (string, 50 chars max)
- Lowercase with hyphens
- Must match category code
- Examples: "reentrancy", "access-control"

**4. severity** (enum: critical|high|medium|low|info)
- Based on CVSS or industry standards
- Critical: Immediate exploitation, high impact
- High: Likely exploitation, significant impact
- Medium: Moderate difficulty, moderate impact
- Low: Difficult exploitation, low impact
- Info: No direct security impact

**5. description** (text, 500 chars recommended)
- Clear explanation of vulnerability
- Include impact statement
- Avoid jargon where possible

**6. swc_id** (string, optional for non-Solidity)
- Format: `SWC-###`
- Reference: https://swcregistry.io/
- Required for Solidity/Vyper patterns

**7. cwe_id** (string, required)
- Format: `CWE-###`
- Reference: https://cwe.mitre.org/
- Use most specific CWE possible

**8. owasp_category** (string, required)
- Reference: OWASP Smart Contract Top 10 or OWASP Top 10
- Format: "A#: Category Name"
- Examples: "A4: Insecure Design", "A9: Code Quality"

**9. remediation** (text, required)
- Clear, actionable fix guidance
- 1-3 sentences
- Focus on "how to fix", not "what is broken"

**10. fix_examples** (array of strings, min 2 required)
- Specific code-level fixes
- Actionable recommendations
- At least 2 different approaches

**11. references** (array of strings, min 2 required)
- Authoritative sources only
- Include URLs
- Examples: SWC Registry, official docs, audit reports

**12. detection_methods** (array of strings, required)
- Values: "static", "symbolic", "fuzzing", "formal", "manual"
- Include all applicable methods

**13. false_positive_rate** (float, 0.0-1.0, required)
- Estimated false positive rate
- Based on empirical data or expert judgment
- 0.0 = never false positive, 1.0 = always false positive

**14. affected_languages** (array of strings, required)
- Values: "solidity", "vyper", "rust", "cairo", etc.
- Include all affected languages

**15. semantic_description** (text, required)
- Enhanced description for ML/semantic matching
- Include technical details
- Use keywords from domain

**16. keywords** (array of strings, min 3 required)
- Key terms for semantic matching
- Include variations and synonyms
- Use lowercase

### Pattern Quality Guidelines

1. **Clarity**: Descriptions must be understandable by developers
2. **Accuracy**: Technical details must be correct
3. **Completeness**: All required fields must have meaningful values
4. **Consistency**: Follow existing pattern examples
5. **Actionability**: Remediation must be implementable

### Pattern Validation

All patterns must pass JSON schema validation:

```python
# Validate pattern structure
python scripts/validate_patterns.py

# Expected output:
# ✓ All patterns valid
# ✓ No duplicate IDs
# ✓ All required fields present
```

---

## Mapping Creation Standards

### Mapping Format

```json
{
  "pattern_id": "BVD-XXX-###",
  "scanner_id": "scanner-name",
  "detector_id": "detector-name",
  "match_type": "exact"
}
```

### Match Type Guidelines

**1. exact** (preferred)
- 1:1 correspondence between detector and pattern
- Detector ALWAYS indicates this vulnerability
- Accuracy >90%
- Examples:
  - slither:reentrancy-eth → BVD-SOLIDITY-REE-001
  - aderyn:tx-origin-auth → BVD-SOLIDITY-ACC-006

**2. fuzzy**
- Close match, minor variations
- Detector USUALLY indicates this vulnerability
- Accuracy 80-90%
- Examples:
  - Detector checks subset of vulnerability
  - Pattern is more general than detector

**3. semantic**
- ML-based or contextual match
- Detector SOMETIMES indicates this vulnerability
- Accuracy <80%
- Use sparingly
- Requires additional validation

### Mapping Quality Requirements

1. **Accuracy**: Test each mapping with sample findings
2. **Documentation**: Document reasoning for non-exact matches
3. **Validation**: Peer review all mappings
4. **Testing**: Include mapping in integration tests

### Finding Existing Patterns

Before creating new patterns, search existing patterns:

```bash
# Search by keyword
grep -i "keyword" seeds/vulnerability_patterns.json

# Search by category
jq '.patterns[] | select(.category=="reentrancy")' seeds/vulnerability_patterns.json

# Search by SWC
jq '.patterns[] | select(.swc_id=="SWC-107")' seeds/vulnerability_patterns.json
```

### Mapping Conflicts

**Duplicate Detector IDs**: Not allowed
- Each scanner-detector combination can only map to ONE pattern
- Database enforces unique constraint

**Resolution**:
- Choose most specific pattern
- Document in comments why alternative was rejected

---

## Database Migration Requirements

### Alembic Migration Structure

**File Naming**: `YYYYMMDD_HHMM-###_descriptive_name.py`

Example: `20251029_1600-011_aderyn_100_percent_integration.py`

### Migration Template

```python
"""scanner integration vX.Y

Revision ID: ###
Revises: previous_revision
Create Date: YYYY-MM-DD HH:MM:SS.000000

Intelligence Platform vX.Y: Scanner Integration
- Add N new vulnerability patterns
- Add M new detector-to-pattern mappings
- Scanner coverage: X/Y detectors (Z%)
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = '###'
down_revision: Union[str, None] = 'previous'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """
    Add N new vulnerability patterns and M new detector mappings.
    All operations are idempotent using ON CONFLICT DO NOTHING.
    """

    # ==========================================
    # Insert New Vulnerability Patterns
    # ==========================================

    patterns = [
        {
            'id': 'BVD-XXX-###',
            'name': 'Pattern Name',
            'description': 'Description',
            'category': 'category',
            'severity': 'high',
            'swc_id': 'SWC-###',
            'cwe_id': 'CWE-###',
            'owasp_category': 'A#: Category',
            'remediation': 'Fix description',
            'fix_examples': ['Example 1', 'Example 2'],
            'references': ['URL 1', 'URL 2'],
            'detection_methods': ['static'],
            'false_positive_rate': 0.1,
            'affected_languages': ['solidity'],
            'semantic_description': 'Detailed description',
            'keywords': ['keyword1', 'keyword2', 'keyword3']
        },
        # ... more patterns
    ]

    # Insert patterns with conflict handling (idempotent)
    for pattern in patterns:
        op.execute(f"""
            INSERT INTO vulnerability_patterns (
                id, name, description, category, severity,
                swc_id, cwe_id, owasp_category, remediation,
                fix_examples, references, detection_methods,
                false_positive_rate, affected_languages,
                semantic_description, keywords, is_active
            ) VALUES (
                '{pattern['id']}',
                '{pattern['name']}',
                $${pattern['description']}$$,
                '{pattern['category']}',
                '{pattern['severity']}',
                '{pattern['swc_id']}',
                '{pattern['cwe_id']}',
                '{pattern['owasp_category']}',
                $${pattern['remediation']}$$,
                %s::jsonb,
                %s::jsonb,
                ARRAY{pattern['detection_methods']}::varchar[],
                {pattern['false_positive_rate']},
                ARRAY{pattern['affected_languages']}::varchar[],
                $${pattern['semantic_description']}$$,
                ARRAY{pattern['keywords']}::text[],
                true
            )
            ON CONFLICT (id) DO NOTHING;
        """, (
            json.dumps(pattern['fix_examples']),
            json.dumps(pattern['references'])
        ))

    # ==========================================
    # Insert New Detector Mappings
    # ==========================================

    mappings = [
        {'pattern_id': 'BVD-XXX-###', 'detector_id': 'detector-name'},
        # ... more mappings
    ]

    # Insert mappings with conflict handling (idempotent)
    for mapping in mappings:
        op.execute(f"""
            INSERT INTO pattern_tool_mappings (
                pattern_id, scanner_id, detector_id, match_type, is_active
            ) VALUES (
                '{mapping['pattern_id']}',
                '<scanner-name>',
                '{mapping['detector_id']}',
                'exact',
                true
            )
            ON CONFLICT (scanner_id, detector_id) DO NOTHING;
        """)

    print("✅ Migration ###: Added N patterns and M mappings for <Scanner> integration")


def downgrade() -> None:
    """
    Remove N vulnerability patterns and M detector mappings.
    Patterns are removed via CASCADE to automatically remove mappings.
    """

    # Pattern IDs to remove
    pattern_ids = [
        'BVD-XXX-###',
        # ... more pattern IDs
    ]

    # Detector IDs to remove
    detector_ids = [
        'detector-name',
        # ... more detector IDs
    ]

    # Remove mappings
    for detector_id in detector_ids:
        op.execute(f"""
            DELETE FROM pattern_tool_mappings
            WHERE scanner_id = '<scanner-name>'
            AND detector_id = '{detector_id}';
        """)

    # Remove patterns (CASCADE will handle remaining mappings if any)
    for pattern_id in pattern_ids:
        op.execute(f"""
            DELETE FROM vulnerability_patterns
            WHERE id = '{pattern_id}';
        """)

    print("✅ Migration ### rollback: Removed N patterns and M mappings")
```

### Migration Requirements

1. **Idempotent Operations**:
   - MUST use `ON CONFLICT DO NOTHING`
   - Migration can be run multiple times safely
   - No errors if data already exists

2. **Complete Rollback**:
   - `downgrade()` MUST reverse all changes
   - Test rollback before committing
   - Document any data loss implications

3. **Error Handling**:
   - Use transactions where appropriate
   - Log success/failure messages
   - Provide clear error messages

4. **Performance**:
   - Batch operations where possible
   - Avoid N+1 queries
   - Consider index creation for large datasets

### Testing Migrations

**Local Testing Workflow**:

```bash
# 1. Create backup
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PGPASSWORD=postgres pg_dump -h 127.0.0.1 -p 5432 -U postgres solidity_security | \
  gzip > backups/pre_migration_test_$(date +%Y%m%d_%H%M%S).sql.gz

# 2. Check current state
alembic current

# 3. Test upgrade
alembic upgrade head

# 4. Verify patterns inserted
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-XXX-%';"

# 5. Test downgrade
alembic downgrade -1

# 6. Verify patterns removed
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-XXX-%';"

# 7. Re-apply migration
alembic upgrade head
```

**Testing Checklist**:
- [ ] Backup created before testing
- [ ] Upgrade runs without errors
- [ ] Patterns inserted correctly
- [ ] Mappings inserted correctly
- [ ] Downgrade runs without errors
- [ ] Patterns removed correctly
- [ ] Mappings removed correctly
- [ ] Re-upgrade works correctly

---

## Testing Requirements

### Test Coverage Standards

**Minimum Coverage**: 90% for all new code

**Required Test Suites**:
1. Pattern database validation tests
2. Pattern matching tests
3. Cross-tool deduplication tests
4. Sample vulnerable contract tests

### Test Suite 1: Pattern Database Validation

**File**: `tests/integration/test_<scanner>_integration_complete.py`

**Required Tests**:

```python
def test_100_percent_coverage():
    """Verify all scanner detectors are mapped"""
    assert len(scanner_mappings) == TOTAL_DETECTORS

def test_version_updated():
    """Verify pattern database version incremented"""
    assert data['version'] == 'X.Y'

def test_total_patterns_count():
    """Verify total pattern count"""
    assert len(data['patterns']) == EXPECTED_COUNT

def test_all_mappings_exist():
    """Verify all detector mappings are present"""
    for detector_id in expected_detectors:
        assert detector_id in mapped_detectors

def test_new_patterns_exist():
    """Verify new patterns were created"""
    for pattern_id in new_pattern_ids:
        assert pattern_id in patterns

def test_pattern_attributes():
    """Verify new patterns have correct attributes"""
    for pattern_id in new_pattern_ids:
        pattern = patterns[pattern_id]
        assert pattern['name'] == expected_name
        assert pattern['severity'] == expected_severity

def test_no_duplicate_mappings():
    """Verify no duplicate detector mappings"""
    detector_ids = [m['detector_id'] for m in scanner_mappings]
    assert len(detector_ids) == len(set(detector_ids))

def test_pattern_metadata_completeness():
    """Verify all required fields present"""
    required_fields = ['id', 'name', 'category', 'severity', ...]
    for pattern in new_patterns:
        for field in required_fields:
            assert field in pattern
            assert pattern[field] is not None
```

### Test Suite 2: Pattern Matching Tests

**File**: `tests/integration/test_<scanner>_pattern_matching.py`

**Required Tests**:

```python
def simulate_scanner_finding(detector_id, location):
    """Helper to simulate scanner finding"""
    return {
        'scanner_id': 'scanner-name',
        'detector_id': detector_id,
        'location': location,
        # ... other fields
    }

def apply_pattern_matching(finding):
    """Helper to apply pattern matching logic"""
    # Simulate Phase 4D pattern matching
    pattern_id = mappings.get(finding['detector_id'])
    if pattern_id:
        finding['pattern_id'] = pattern_id
        finding['matched'] = True
    return finding

def test_<detector>_pattern_matching():
    """Test specific detector maps correctly"""
    finding = simulate_scanner_finding('detector-id', 'file.sol:10')
    enriched = apply_pattern_matching(finding)

    assert enriched['matched'] is True
    assert enriched['pattern_id'] == 'BVD-XXX-###'
    assert enriched['category'] == 'expected-category'

def test_all_detectors_have_mappings():
    """Verify all detectors have pattern mappings"""
    for detector_id in all_detector_ids:
        assert detector_id in mappings
```

### Test Suite 3: Cross-Tool Deduplication Tests

**File**: `tests/integration/test_<scanner>_pattern_matching.py`

**Required Tests**:

```python
def generate_fingerprint(pattern_id, location):
    """Generate fingerprint for deduplication"""
    import hashlib
    return hashlib.sha256(f"{pattern_id}|{location}".encode()).hexdigest()

def test_<vulnerability>_deduplication_across_tools():
    """Test findings from multiple scanners deduplicate"""
    pattern_id = 'BVD-XXX-###'
    location = 'Contract.sol:25:functionName()'

    # Simulate findings from different scanners
    scanner1_finding = {'scanner_id': 'scanner1', 'pattern_id': pattern_id, 'location': location}
    scanner2_finding = {'scanner_id': 'scanner2', 'pattern_id': pattern_id, 'location': location}

    # Generate fingerprints
    fp1 = generate_fingerprint(pattern_id, location)
    fp2 = generate_fingerprint(pattern_id, location)

    # Same pattern + location = same fingerprint
    assert fp1 == fp2

def test_fingerprint_consistency():
    """Test fingerprints are consistent"""
    pattern_id = 'BVD-XXX-###'
    location = 'file.sol:10'

    fp1 = generate_fingerprint(pattern_id, location)
    fp2 = generate_fingerprint(pattern_id, location)

    assert fp1 == fp2

def test_different_locations_different_fingerprints():
    """Test different locations have different fingerprints"""
    pattern_id = 'BVD-XXX-###'

    fp1 = generate_fingerprint(pattern_id, 'file1.sol:10')
    fp2 = generate_fingerprint(pattern_id, 'file2.sol:20')

    assert fp1 != fp2
```

### Test Suite 4: Sample Vulnerable Contracts

**File**: `tests/fixtures/contracts/solidity/Vulnerable<Scanner>Test.sol`

**Requirements**:
- Create intentionally vulnerable contract
- Include vulnerabilities for each new pattern
- Document which lines trigger which detectors
- Test that scanner actually detects vulnerabilities

**Example**:

```solidity
// tests/fixtures/contracts/solidity/VulnerableScannerTest.sol
pragma solidity ^0.8.20;

/**
 * @title VulnerableScannerTest
 * @dev Intentionally vulnerable contract for testing scanner integration
 */
contract VulnerableScannerTest {
    // BVD-SOLIDITY-XXX-001: Vulnerability Name (Line 15)
    function vulnerableFunction() public {
        // Vulnerable code here
    }

    // BVD-SOLIDITY-XXX-002: Another Vulnerability (Line 20)
    function anotherVulnerable() public {
        // Vulnerable code here
    }
}
```

### Running Tests

```bash
# Run all integration tests
pytest tests/integration/test_<scanner>*.py -v

# Run with coverage
pytest tests/integration/test_<scanner>*.py -v --cov=src --cov-report=html

# Run specific test suite
pytest tests/integration/test_<scanner>_integration_complete.py -v
```

---

## Documentation Requirements

### Required Documents

#### 1. Integration Summary

**Location**: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/<SCANNER>-INTELLIGENCE-INTEGRATION-COMPLETE.md`

**Required Sections**:
- Executive Summary (metrics, completion %)
- Integration Overview (timeline, phases)
- Pattern Breakdown (by category, severity)
- Mapping Quality Distribution (exact/fuzzy/semantic %)
- Testing Evidence (test counts, pass rate)
- Cross-Tool Deduplication Examples
- Business Impact Analysis
- Lessons Learned
- Next Steps

**Template**: See `ADERYN-INTELLIGENCE-INTEGRATION-COMPLETE.md` as reference

#### 2. Release Notes

**Location**: `/Users/pwner/Git/ABS/blocksecops-api-service/RELEASE-NOTES-vX.Y.md`

**Required Sections**:
- Version number and date
- Summary of changes
- New patterns (with BVD IDs and descriptions)
- New mappings (scanner coverage %)
- Breaking changes (or "None")
- Migration instructions
- Rollback instructions
- Testing performed
- Known issues (or "None")
- Performance impact assessment
- Security implications

**Format**:
```markdown
# Release Notes v3.0

**Version**: 2.1.0
**Date**: October 29, 2025
**Type**: Minor Release - Intelligence Platform Enhancement

## Summary

Complete <Scanner> static analyzer integration achieving 100% detector coverage...

## Changes

### New Vulnerability Patterns (5 added)

1. **BVD-SOLIDITY-XXX-001**: Pattern Name
   - Severity: high
   - Category: category-name
   - SWC: SWC-###
   - Description: ...

...

### New Detector Mappings (14 added)

- Scanner coverage: X/Y (Z%)
- Mapping quality: 90% exact, 10% fuzzy
- Cross-tool deduplication enabled

### Breaking Changes

None. This is a backward-compatible addition.

## Migration Instructions

```bash
# 1. Backup database
...

# 2. Run migration
...
```

## Rollback Instructions

```bash
# Rollback migration
alembic downgrade -1
```

## Testing

- Integration tests: 38/38 passing
- Pattern matching: 100% validated
- Deduplication: Verified across tools

## Performance Impact

- Database size: +50KB (5 patterns, 14 mappings)
- Query performance: No regression
- Memory usage: Negligible increase

## Security Implications

No security vulnerabilities introduced. Enhances security posture by enabling pattern matching for <Scanner> findings.
```

#### 3. JIRA Updates

**Required Actions**:
- Update story status to "Done"
- Add completion metrics (X/Y detectors, Z%)
- Link PRs and documentation
- Attach testing evidence (screenshots, test reports)
- Update epic progress bar

**JIRA Story Template**:
```
Status: Done
Completion: 100% (X/Y detectors)

Summary:
Successfully integrated <Scanner> with intelligence platform.

Details:
- Added N new vulnerability patterns
- Added M new detector mappings
- Integration coverage: X/Y (Z%)
- All tests passing (38/38)
- Documentation complete

Links:
- PR: https://github.com/.../pull/###
- Release Notes: RELEASE-NOTES-vX.Y.md
- Integration Summary: <SCANNER>-INTELLIGENCE-INTEGRATION-COMPLETE.md

Testing Evidence:
[Attach test report showing 100% pass rate]
```

#### 4. Tracking Documents

**Files to Update**:

1. `INTELLIGENCE-INTEGRATION-TASKS.md`:
   - Update story status to "Complete"
   - Update platform coverage percentage
   - Update completion metrics
   - Add next steps

2. `SCANNER-DETECTOR-TRACKING.md`:
   - Update scanner integration status
   - Update detector count
   - Update coverage percentage
   - Document new patterns created

3. Scanner-specific plans (if applicable):
   - Mark phases as complete
   - Document lessons learned
   - Archive or remove if integration complete

---

## Production Deployment Checklist

### Pre-Deployment

- [ ] **Code Complete**
  - [ ] All code merged to main
  - [ ] No pending PRs
  - [ ] No merge conflicts

- [ ] **Testing**
  - [ ] All tests passing (100%)
  - [ ] Integration tests run in local environment
  - [ ] Migration tested in local environment
  - [ ] Rollback tested in local environment

- [ ] **Database**
  - [ ] Production backup created
  - [ ] Backup verified (can be restored)
  - [ ] Migration is idempotent
  - [ ] Rollback function complete

- [ ] **Documentation**
  - [ ] Release notes created
  - [ ] Migration instructions clear
  - [ ] Rollback procedure documented
  - [ ] JIRA updated

- [ ] **Communication**
  - [ ] Team notified of deployment window
  - [ ] Stakeholders informed
  - [ ] Monitoring alerts configured

### Deployment Steps

- [ ] Create production backup
- [ ] Build Docker image with `--no-cache`
- [ ] Push Docker image to registry
- [ ] Deploy to Kubernetes (zero-downtime)
- [ ] Run database migration
- [ ] Verify deployment health
- [ ] Verify pattern count
- [ ] Verify mapping count
- [ ] Monitor logs for errors

### Post-Deployment

- [ ] Health checks passing
- [ ] All services responding
- [ ] No errors in logs (1 hour monitoring)
- [ ] Pattern matching working
- [ ] Scanner integration functional
- [ ] Team notified of success
- [ ] Update deployment log

### Rollback Triggers

Rollback immediately if:
- Migration fails
- Pattern insertion errors
- Intelligence service crashes
- API errors increase >10%
- Performance degradation >10%
- Any production errors

---

## Quality Gates

### Quality Gate 1: Planning Approval
**Phase**: After Phase 1 (Analysis & Planning)
**Criteria**:
- [ ] Scanner analysis document complete
- [ ] Pattern gap analysis documented
- [ ] Integration plan approved by tech lead
- [ ] Timeline realistic (15-28 hours)
- [ ] Risks identified and mitigated

**Reviewer**: Tech Lead
**Decision**: Proceed / Revise Plan

---

### Quality Gate 2: Pattern Validation
**Phase**: After Phase 2 (Pattern Creation)
**Criteria**:
- [ ] All patterns follow BVD format
- [ ] All required fields complete
- [ ] JSON schema validation passes
- [ ] Peer review completed
- [ ] No duplicate pattern IDs

**Reviewer**: Senior Developer + Tech Lead
**Decision**: Approve Patterns / Request Changes

---

### Quality Gate 3: Migration Testing
**Phase**: After Phase 4 (Database Migration)
**Criteria**:
- [ ] Migration runs without errors
- [ ] Migration is idempotent
- [ ] Rollback tested successfully
- [ ] Database backup created
- [ ] Local testing complete

**Reviewer**: Database Administrator + Tech Lead
**Decision**: Approve Migration / Request Changes

---

### Quality Gate 4: Integration Testing
**Phase**: After Phase 5 (Integration Testing)
**Criteria**:
- [ ] All tests passing (100%)
- [ ] Test coverage ≥90%
- [ ] Pattern matching validated
- [ ] Deduplication validated
- [ ] Sample contracts tested

**Reviewer**: QA Engineer + Senior Developer
**Decision**: Approve for Documentation / Fix Failures

---

### Quality Gate 5: Code Review
**Phase**: After Phase 7 (Code Review & Approval)
**Criteria**:
- [ ] Code quality acceptable
- [ ] No security vulnerabilities
- [ ] Performance acceptable
- [ ] Documentation complete
- [ ] 2+ approvals obtained

**Reviewer**: 2+ Team Members
**Decision**: Approve for Merge / Request Changes

---

### Quality Gate 6: Production Readiness
**Phase**: Before Phase 8 (Production Deployment)
**Criteria**:
- [ ] All previous gates passed
- [ ] Production backup created
- [ ] Rollback plan documented
- [ ] Team notified
- [ ] Monitoring configured

**Reviewer**: Tech Lead + Operations
**Decision**: Deploy / Delay Deployment

---

## Rollback Procedures

### When to Rollback

**Immediate Rollback Required** if:
- Database migration fails
- Pattern insertion errors occur
- Intelligence service crashes
- API response time increases >10%
- Error rate increases >5%
- Any production errors occur

**Monitoring Period**: 1 hour after deployment

### Rollback Methods

#### Method 1: Alembic Downgrade (Preferred)

```bash
# 1. Check current migration
kubectl exec -it deployment/api-service -n production -- alembic current

# 2. Downgrade one revision
kubectl exec -it deployment/api-service -n production -- alembic downgrade -1

# 3. Verify patterns removed
kubectl exec -it deployment/postgresql -n production -- \
  psql -U postgres -d solidity_security \
  -c "SELECT COUNT(*) FROM vulnerability_patterns WHERE id LIKE 'BVD-XXX-%';"

# 4. Restart services
kubectl rollout restart deployment/api-service -n production
```

#### Method 2: Application Rollback

```bash
# 1. Rollback Kubernetes deployment
kubectl rollout undo deployment/api-service -n production

# Or deploy previous version explicitly
kubectl set image deployment/api-service \
  api-service=blocksecops/api-service:PREVIOUS_VERSION \
  -n production

# 2. Verify rollback
kubectl rollout status deployment/api-service -n production
```

#### Method 3: Database Restore (Last Resort)

```bash
# 1. Scale down API service
kubectl scale deployment api-service -n production --replicas=0

# 2. Restore from backup
BACKUP_FILE="/path/to/backup/production_pre_vX.Y_YYYYMMDD_HHMMSS.sql.gz"

kubectl exec -it deployment/postgresql -n production -- bash -c "
  gunzip | psql -U postgres -d solidity_security
" < <(gunzip -c $BACKUP_FILE)

# 3. Scale up API service
kubectl scale deployment api-service -n production --replicas=3

# 4. Verify restoration
kubectl logs -f deployment/api-service -n production
```

### Post-Rollback Actions

After successful rollback:

1. **Document Incident**:
   - What caused rollback?
   - What was the impact?
   - How long was the outage?
   - What data was lost (if any)?

2. **Root Cause Analysis**:
   - Identify root cause
   - Document lessons learned
   - Create prevention plan

3. **Communication**:
   - Notify team of rollback
   - Inform stakeholders
   - Update JIRA with incident details

4. **Plan Remediation**:
   - Fix identified issues
   - Re-test thoroughly
   - Schedule re-deployment

---

## Templates and Examples

### Pattern Creation Template

```json
{
  "id": "BVD-XXX-###",
  "name": "Pattern Name (Title Case)",
  "category": "category-name-lowercase",
  "severity": "high",
  "description": "Clear description of vulnerability with impact statement",
  "swc_id": "SWC-###",
  "cwe_id": "CWE-###",
  "owasp_category": "A#: Category Name",
  "remediation": "Clear, actionable fix guidance in 1-3 sentences",
  "fix_examples": [
    "Specific code-level fix approach 1",
    "Specific code-level fix approach 2",
    "Alternative fix approach 3"
  ],
  "references": [
    "https://swcregistry.io/docs/SWC-###",
    "https://docs.soliditylang.org/en/latest/...",
    "https://consensys.github.io/smart-contract-best-practices/..."
  ],
  "detection_methods": ["static", "symbolic", "fuzzing"],
  "false_positive_rate": 0.1,
  "affected_languages": ["solidity", "vyper"],
  "semantic_description": "Enhanced technical description with domain keywords for ML/semantic matching",
  "keywords": [
    "keyword1",
    "keyword2",
    "keyword3",
    "related-term",
    "synonym"
  ]
}
```

### Mapping Creation Template

```json
{
  "pattern_id": "BVD-XXX-###",
  "scanner_id": "scanner-name",
  "detector_id": "scanner-specific-detector-id",
  "match_type": "exact"
}
```

### Integration Plan Template

```markdown
# <Scanner> Integration Plan

**Version**: 1.0
**Date**: YYYY-MM-DD
**Estimated Effort**: 15-28 hours

## Scanner Overview

- **Name**: <Scanner Name>
- **Version**: X.Y.Z
- **Total Detectors**: N
- **Severity Breakdown**:
  - Critical: X
  - High: Y
  - Medium: Z
  - Low: A
  - Info: B

## Pattern Analysis

### Detectors Mapping to Existing Patterns (M detectors)

| Detector ID | Existing Pattern | Match Quality |
|-------------|------------------|---------------|
| detector-1  | BVD-SOLIDITY-XXX-001     | EXACT         |
| detector-2  | BVD-SOLIDITY-XXX-002     | FUZZY         |
| ...         | ...             | ...           |

### Detectors Requiring New Patterns (P detectors)

| Detector ID | New Pattern ID | Category | Severity |
|-------------|----------------|----------|----------|
| detector-3  | BVD-SOLIDITY-YYY-001   | category | high     |
| detector-4  | BVD-SOLIDITY-YYY-002   | category | medium   |
| ...         | ...            | ...      | ...      |

## Timeline

- Phase 1: Analysis & Planning - 2-4 hours ✓ (complete)
- Phase 2: Pattern Creation - 4-8 hours (in progress)
- Phase 3: Mapping Creation - 2-4 hours
- Phase 4: Database Migration - 1-2 hours
- Phase 5: Integration Testing - 2-3 hours
- Phase 6: Documentation - 2-3 hours
- Phase 7: Code Review - 1-2 hours
- Phase 8: Production Deployment - 1-2 hours

**Total**: 15-28 hours

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Database migration fails | High | Mandatory backup before migration |
| Pattern quality issues | Medium | Peer review + validation |
| Test failures | Medium | Comprehensive test suite |

## Success Criteria

- [ ] 100% detector coverage (N/N detectors)
- [ ] All tests passing
- [ ] Documentation complete
- [ ] Production deployment successful
```

### Commit Message Template

```
feat(intelligence): Complete <Scanner> integration to 100% (X/Y detectors)

Achieve 100% <Scanner> detector coverage by adding N new patterns and M mappings. Increases platform intelligence coverage from A% to B%.

Pattern Database Changes:
- Added N new patterns:
  * BVD-SOLIDITY-XXX-001: Pattern Name 1
  * BVD-SOLIDITY-XXX-002: Pattern Name 2
  * ...

- Added M new detector mappings (P to existing + Q to new patterns)
- Version: X.Y → X.Z
- Total patterns: A → B
- Total mappings: C → D

Integration:
- All Y <Scanner> detectors now map to vulnerability patterns
- High-severity: X/Y (Z%)
- Medium-severity: A/B (C%)
- Low-severity: D/E (F%)
- Cross-tool deduplication enabled

Testing:
- N integration tests passing
- Pattern matching validated
- Cross-tool deduplication validated
- Sample vulnerable contracts created

Database:
- Alembic migration ### created
- Idempotent pattern insertion
- Rollback support included

BREAKING CHANGES: None

Closes PROJ-###
```

### PR Description Template

```markdown
## Summary

Complete <Scanner> static analyzer integration achieving 100% detector coverage (X/Y detectors). This milestone enables full intelligence enrichment for all <Scanner> findings including pattern matching, cross-tool deduplication, and unified severity scoring.

## Changes

### Pattern Database (vX.Y → vX.Z)
- ✅ Added N new patterns
- ✅ Added M new detector mappings (P existing + Q new)
- ✅ Total patterns: A → B
- ✅ Total mappings: C → D
- ✅ <Scanner> coverage: X/Y (100%)

### Database Migration
- ✅ Alembic migration ### created
- ✅ Idempotent INSERT operations
- ✅ Rollback support included
- ✅ Tested in local environment

### New Vulnerability Patterns

1. **BVD-SOLIDITY-XXX-001**: Pattern Name 1
   - Severity: high
   - Category: category-name
   - SWC: SWC-###

2. **BVD-SOLIDITY-XXX-002**: Pattern Name 2
   - Severity: medium
   - Category: category-name
   - SWC: SWC-###

...

### Testing
- ✅ N integration tests passing
- ✅ Pattern matching validation (X/X tests)
- ✅ Cross-tool deduplication validation (Y/Y tests)
- ✅ Database migration tested
- ✅ Rollback tested

### Impact
- Platform coverage: A% → B% (+Cpp)
- <Scanner> findings now fully enriched with intelligence
- Cross-tool deduplication operational
- Scanner achieves 100% integration milestone

## Testing Performed

- [x] Unit tests passing (N/N)
- [x] Integration tests passing (all)
- [x] Database migration tested locally
- [x] Rollback tested
- [x] Pattern matching validated
- [x] Deduplication validated
- [x] JSON structure validated

## Migration Instructions

```bash
# 1. Backup database
./scripts/backup-local-db.sh

# 2. Run migration
alembic upgrade head

# 3. Verify patterns
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT COUNT(*) FROM pattern_tool_mappings WHERE scanner_id='<scanner>';"
# Expected: Y
```

## Rollback Instructions

```bash
# Rollback migration
alembic downgrade -1

# Restore from backup if needed
BACKUP_FILE="/path/to/backup.sql.gz"
gunzip -c "$BACKUP_FILE" | PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security
```

## Breaking Changes
None. This is a backward-compatible addition.

## Related Issues
- Closes PROJ-### (Story X.Y: <Scanner> Integration)
- Contributes to EPIC-### (Intelligence Integration)

## Documentation
- Release notes: `RELEASE-NOTES-vX.Y.md`
- Implementation plan: `<scanner>_integration_plan.md`
- Complete summary: `<SCANNER>-INTELLIGENCE-INTEGRATION-COMPLETE.md`

## Checklist
- [x] Code follows project style guidelines
- [x] All tests passing
- [x] Documentation updated
- [x] Database backup created
- [x] Migration tested locally
- [x] Rollback tested
- [x] Release notes created
- [x] JIRA tickets updated
```

---

## Common Pitfalls

### Pitfall 1: Skipping Database Migration

**Problem**: Updating JSON seed file but not creating Alembic migration

**Impact**:
- Production database doesn't have new patterns
- Intelligence service fails to match findings
- Pattern matching returns no results
- Cross-tool deduplication broken

**Solution**:
- ALWAYS create Alembic migration (Phase 4)
- Test migration in local environment
- Never rely solely on JSON seed file

**Prevention**:
- Include migration in integration checklist
- Code review must verify migration exists
- CI/CD should check for migration file

---

### Pitfall 2: Skipping Database Backup

**Problem**: Running migration without backup

**Impact**:
- No recovery if migration fails
- Risk of data loss
- Extended downtime
- Cannot rollback safely

**Solution**:
- ALWAYS create backup before migration (mandatory)
- Verify backup can be restored
- Test rollback procedure

**Prevention**:
- Automate backup in deployment script
- Deployment blocked without backup
- Backup verification step in checklist

---

### Pitfall 3: Non-Idempotent Migrations

**Problem**: Migration fails if run multiple times

**Impact**:
- Cannot retry failed migrations
- Duplicate key errors
- Inconsistent database state

**Solution**:
- Use `ON CONFLICT DO NOTHING` for all inserts
- Test migration can run multiple times
- Verify idempotency in code review

**Prevention**:
- Migration template includes ON CONFLICT
- Testing checklist includes re-run test
- Code review verifies idempotency

---

### Pitfall 4: Missing Rollback Function

**Problem**: `downgrade()` not implemented or incomplete

**Impact**:
- Cannot rollback deployment
- Stuck with broken changes
- Requires manual database surgery

**Solution**:
- Implement complete `downgrade()` function
- Test rollback before committing
- Document rollback procedure

**Prevention**:
- Migration template includes downgrade
- Testing checklist includes rollback test
- Code review verifies rollback works

---

### Pitfall 5: Insufficient Testing

**Problem**: Skipping integration tests or sample contracts

**Impact**:
- Bugs discovered in production
- Pattern matching failures
- User-facing errors

**Solution**:
- Create comprehensive test suite
- Test all new patterns
- Validate all mappings
- Use sample vulnerable contracts

**Prevention**:
- Testing is a quality gate
- CI/CD enforces test coverage
- Code review checks test completeness

---

### Pitfall 6: Incomplete Documentation

**Problem**: Missing release notes, JIRA updates, or tracking docs

**Impact**:
- No audit trail
- Team confusion
- Difficult to troubleshoot issues
- Knowledge loss

**Solution**:
- Complete all documentation (Phase 6)
- Update all tracking documents
- Create comprehensive release notes
- Update JIRA with evidence

**Prevention**:
- Documentation is a quality gate
- Template checklist for all docs
- Peer review documentation

---

### Pitfall 7: Pattern ID Conflicts

**Problem**: Reusing pattern IDs or incorrect numbering

**Impact**:
- Database unique constraint violations
- Migration failures
- Data inconsistency

**Solution**:
- Check existing patterns before creating new IDs
- Follow sequential numbering within category
- Never reuse deleted IDs

**Prevention**:
- Pattern creation checklist includes ID validation
- Code review verifies no conflicts
- Script to check for duplicates

---

### Pitfall 8: Poor Match Quality

**Problem**: Using fuzzy/semantic matches when exact match possible

**Impact**:
- Reduced accuracy
- More false positives
- User confusion

**Solution**:
- Prefer exact matches (>90%)
- Document reasoning for non-exact matches
- Test match accuracy

**Prevention**:
- Mapping quality review in code review
- Quality gate for match types
- Test cases for each mapping

---

### Pitfall 9: Missing Scanner Configuration

**Problem**: Scanner not configured in `scanners.py`

**Impact**:
- Scanner not available in UI
- Orchestration fails
- Users cannot run scanner

**Solution**:
- Verify scanner in `src/infrastructure/scanner_config/scanners.py`
- Add to appropriate language presets
- Test scanner selection in UI

**Prevention**:
- Integration plan includes scanner config check
- Code review verifies scanner configured
- UI testing includes scanner selection

---

### Pitfall 10: Skipping Intelligence Service Validation

**Problem**: Not verifying intelligence service handles new patterns

**Impact**:
- Runtime errors
- Findings not enriched
- Pattern matching broken

**Solution**:
- Verify normalizer exists for scanner
- Test intelligence service with sample findings
- Validate Phase 4D pattern matching works

**Prevention**:
- Integration testing includes intelligence service
- Code review checks normalizer
- End-to-end test with actual scanner output

---

## Compliance Checklist

Use this checklist for every intelligence integration:

### Phase 1: Analysis & Planning
- [ ] Scanner analysis document created
- [ ] Total detector count documented
- [ ] Severity breakdown documented
- [ ] Pattern gap analysis complete
- [ ] Integration plan created with timeline
- [ ] Risk assessment documented
- [ ] Plan reviewed and approved

### Phase 2: Pattern Creation
- [ ] All patterns follow BVD-XXX-### format
- [ ] All required fields complete
- [ ] At least 2 fix examples per pattern
- [ ] At least 2 references per pattern
- [ ] SWC/CWE mappings verified
- [ ] Keywords for semantic matching included
- [ ] JSON schema validation passes
- [ ] Peer review completed

### Phase 3: Mapping Creation
- [ ] All detectors mapped to patterns
- [ ] Match types documented (prefer exact)
- [ ] Mapping quality rationale provided
- [ ] Sample findings collected for validation
- [ ] No duplicate mappings
- [ ] Peer review completed

### Phase 4: Database Migration
- [ ] Alembic migration file created
- [ ] Migration follows naming convention
- [ ] Migration is idempotent (ON CONFLICT DO NOTHING)
- [ ] Complete downgrade function implemented
- [ ] Database backup created
- [ ] Backup verified (can be restored)
- [ ] Migration tested locally (upgrade)
- [ ] Migration tested locally (downgrade)
- [ ] Migration tested locally (re-upgrade)
- [ ] Migration revision ID incremented

### Phase 5: Integration Testing
- [ ] Pattern database validation tests created
- [ ] Pattern matching tests created
- [ ] Cross-tool deduplication tests created
- [ ] Sample vulnerable contracts created
- [ ] All tests passing (100%)
- [ ] Test coverage ≥90%
- [ ] Integration tested in local environment
- [ ] Intelligence service validation complete

### Phase 6: Documentation
- [ ] Integration summary document created
- [ ] Release notes created
- [ ] Migration instructions included
- [ ] Rollback instructions included
- [ ] JIRA story updated to "Done"
- [ ] JIRA completion metrics added
- [ ] JIRA links to PRs and docs added
- [ ] Testing evidence attached to JIRA
- [ ] INTELLIGENCE-INTEGRATION-TASKS.md updated
- [ ] SCANNER-DETECTOR-TRACKING.md updated
- [ ] Scanner-specific plan updated (if applicable)

### Phase 7: Code Review & Approval
- [ ] PR created with comprehensive description
- [ ] PR includes migration file
- [ ] PR includes test files
- [ ] PR includes documentation
- [ ] Code follows style guidelines
- [ ] No hardcoded values
- [ ] Proper error handling
- [ ] Efficient algorithms
- [ ] 2+ approvals obtained
- [ ] All comments addressed
- [ ] CI/CD checks passing

### Phase 8: Production Deployment
- [ ] Production database backup created
- [ ] Backup verified (can be restored)
- [ ] Team notified of deployment
- [ ] Monitoring alerts configured
- [ ] Docker image built with --no-cache
- [ ] Docker image pushed to registry
- [ ] Kubernetes deployment updated
- [ ] Database migration run
- [ ] Deployment health verified
- [ ] Pattern count verified
- [ ] Mapping count verified
- [ ] Logs monitored (1 hour, no errors)
- [ ] Scanner tested in production
- [ ] Team notified of success

### Rollback Readiness
- [ ] Rollback procedure documented
- [ ] Rollback tested in local environment
- [ ] Rollback triggers defined
- [ ] Backup restoration tested
- [ ] Alembic downgrade tested
- [ ] Application rollback tested

---

**MANDATORY COMPLIANCE**: All intelligence integration work MUST follow these standards. Non-compliance may result in rejected PRs, blocked deployments, and rollback of changes.
