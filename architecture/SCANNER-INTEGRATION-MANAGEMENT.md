# Scanner Integration Management

**Status:** Planning Document
**Created:** October 21, 2025
**Goal:** Enable users to add/remove security scanners through the dashboard UI

---

## Vision: User-Configurable Scanner Marketplace

Transform the BlockSecOps platform into an open ecosystem where users can:
- Browse available security scanners in a marketplace
- Enable/disable scanners for their organization
- Add custom or third-party scanners
- Configure scanner-specific settings through the UI
- Share scanner configurations across teams

**Key Differentiator:** Unlike competitors with fixed scanner sets, we empower users to build their own security toolchain.

---

## Current State: Manual Integration Process

### How Scanners Are Currently Integrated

Based on the Manticore removal experience (October 2025), here's the complete integration flow:

#### 1. **API Service** (`blocksecops-api-service`)
**File:** `src/infrastructure/scanner_config/scanners.py`

```python
SCANNERS: Dict[str, ScannerMetadata] = {
    "scanner-id": ScannerMetadata(
        id="scanner-id",
        name="Scanner Name",
        description="Scanner description for UI",
        scanner_type=ScannerType.STATIC_ANALYSIS,  # or FUZZING, SYMBOLIC_EXECUTION, etc.
        languages=[ScannerLanguage.SOLIDITY],
        estimated_time_seconds=30,
        requires_compilation=False,
        is_production_ready=True,
        confidence_level="high",
    ),
}
```

**Purpose:** Source of truth for scanner metadata displayed in the dashboard.

#### 2. **Orchestration Service** (`blocksecops-orchestration`)
**File:** `src/blocksecops_orchestration/scanners/registry.py`

- Register scanner executor class
- Implement scanner-specific execution logic
- Handle scanner binary availability checking
- Parse scanner output into standardized format

**File:** `src/blocksecops_orchestration/api/routes/scanners.py`

- Expose scanner availability via `/api/v1/scanners/{scanner_id}/availability`
- Return scanner metadata via `/api/v1/scanners`

#### 3. **Dashboard** (`blocksecops-dashboard`)
**File:** `src/lib/storage/scannerPreferences.ts`

- Store user scanner selections in localStorage
- Manage per-project and per-language defaults
- Provide migration utilities for scanner changes

#### 4. **Deployment**
- Build new Docker images with updated scanner registry
- Update Kubernetes kustomization files with new image tags
- Deploy to Kubernetes cluster
- Restart affected services

### Current Pain Points

1. **Requires Code Changes:** Every scanner addition/removal needs code modifications in multiple repositories
2. **Requires Deployment:** Changes require Docker builds and Kubernetes deployments
3. **No User Control:** Platform administrators control the scanner list, not users
4. **Manual Cleanup:** Browser localStorage needs manual migration scripts
5. **Version Drift:** Docker images can run outdated code if not rebuilt/redeployed

---

## Lessons Learned: Manticore Removal (October 2025)

### What Went Wrong
- **Source code was updated** to remove Manticore on October 20, 2025
- **Docker images were NOT rebuilt**, causing API service v0.2.0 to still return Manticore
- **UI still showed Manticore** even after browser hard refresh because dashboard fetched from stale API

### Root Cause
The platform has **3 deployment artifacts** that must stay synchronized:
1. Source code changes (Git commits)
2. Docker image builds (container registry)
3. Kubernetes deployments (running pods)

**Gap:** No automated CI/CD pipeline ensures (1) triggers (2) triggers (3).

### The Fix
1. Updated `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py` (removed Manticore)
2. Built new Docker image: `api-service:0.3.6`
3. Updated `k8s/overlays/local/api-service/kustomization.yaml` (newTag: 0.3.6)
4. Deployed to Kubernetes: `kubectl apply -k k8s/overlays/local/api-service/`
5. Added localStorage migration in `scannerPreferences.ts` to clean cached Manticore selections

### Key Insight
**The API service is the source of truth** for scanner metadata. The dashboard dynamically fetches from `/api/v1/scanners`, so updating the API service is sufficient to change the UI scanner list.

---

## Future State: Dynamic Scanner Registry

### Phase 1: Database-Backed Scanner Registry (Q1 2026)

Move scanner metadata from hardcoded Python dictionaries to a database table.

**Database Schema:**
```sql
CREATE TABLE scanners (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    scanner_type VARCHAR(50) NOT NULL,
    languages TEXT[] NOT NULL,
    estimated_time_seconds INTEGER,
    version VARCHAR(20),
    developer VARCHAR(100),
    requires_compilation BOOLEAN DEFAULT FALSE,
    is_production_ready BOOLEAN DEFAULT TRUE,
    confidence_level VARCHAR(20) DEFAULT 'high',
    is_enabled BOOLEAN DEFAULT TRUE,
    docker_image VARCHAR(200),  -- Scanner container image
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE scanner_configurations (
    id UUID PRIMARY KEY,
    scanner_id VARCHAR(50) REFERENCES scanners(id),
    organization_id UUID REFERENCES organizations(id),
    custom_config JSONB,  -- Scanner-specific settings
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(scanner_id, organization_id)
);
```

**Benefits:**
- No code changes needed to add/remove scanners
- Scanners can be toggled on/off via database updates
- Per-organization scanner configurations
- Easier rollback (just update database, no deployment)

### Phase 2: Scanner Marketplace UI (Q2 2026)

Build a scanner management interface in the dashboard.

**Features:**
- **Scanner Catalog:** Browse all available scanners with filtering by language/type
- **Enable/Disable Toggle:** One-click scanner activation per organization
- **Scanner Details Page:** View scanner info, version, sample findings, documentation links
- **Configuration Panel:** UI for scanner-specific settings (flags, thresholds, rules)

**Wireframe Locations:**
- `/settings/scanners` - Organization scanner management page
- `/settings/scanners/{scanner_id}` - Individual scanner configuration
- `/projects/{project_id}/scan-config` - Project-specific scanner selection (already exists)

### Phase 3: Plugin Architecture (Q3 2026)

Enable users to add custom scanners without platform code changes.

**Scanner Plugin Specification:**
```yaml
# scanner-plugin.yaml
name: "My Custom Scanner"
id: "my-custom-scanner"
version: "1.0.0"
type: "static_analysis"
languages: ["solidity"]
docker_image: "myregistry/my-scanner:1.0.0"
entrypoint: "/usr/local/bin/my-scanner"
output_format: "sarif"  # or custom parser
configuration_schema:
  - name: "severity_threshold"
    type: "select"
    options: ["low", "medium", "high"]
    default: "medium"
  - name: "max_depth"
    type: "number"
    default: 10
```

**Upload Flow:**
1. User uploads `scanner-plugin.yaml` via dashboard
2. Platform validates schema and tests Docker image availability
3. Scanner registered in database with `custom=true` flag
4. Orchestration service dynamically loads scanner executor
5. Scanner appears in user's scanner catalog

**Security Considerations:**
- Scanners run in isolated containers with resource limits
- Only organization admins can add custom scanners
- Scanner output is sandboxed and validated before storage
- Optional: Require scanner code signing or allowlist Docker registries

### Phase 4: Scanner Marketplace & Community (Q4 2026)

Build a public scanner marketplace for sharing configurations.

**Features:**
- **Public Scanner Registry:** Community-contributed scanner plugins
- **Ratings & Reviews:** Users rate scanner effectiveness and false positive rates
- **Usage Analytics:** "Most popular scanners for Solidity contracts"
- **Vendor Partnerships:** Official integrations with Trail of Bits, Cyfrin, Consensys, etc.
- **One-Click Install:** Install community scanners with pre-configured settings

---

## Implementation Roadmap

### ✅ Completed (October 2025)
- [x] Centralized scanner metadata in API service
- [x] Dashboard dynamically fetches scanners from API
- [x] localStorage-based user preferences for scanner selection
- [x] Documentation of manual integration process

### 🔄 Phase 1: Database-Backed Registry (Q1 2026)
- [ ] Create database migration for `scanners` and `scanner_configurations` tables
- [ ] Migrate hardcoded scanner metadata to database seed data
- [ ] Update API service to read from database instead of Python dict
- [ ] Add API endpoints: `POST /admin/scanners`, `PUT /admin/scanners/{id}`, `DELETE /admin/scanners/{id}`
- [ ] Build admin CLI tool for scanner management
- [ ] Write migration guide for existing scanner preferences

### 📅 Phase 2: Marketplace UI (Q2 2026)
- [ ] Design scanner management UI mockups
- [ ] Implement scanner catalog page with search/filter
- [ ] Build scanner enable/disable toggle with organization-level permissions
- [ ] Create scanner detail page with configuration forms
- [ ] Add scanner version history and changelog tracking
- [ ] Implement scanner usage analytics (how often each scanner is run)

### 📅 Phase 3: Plugin Architecture (Q3 2026)
- [ ] Define scanner plugin specification (YAML schema)
- [ ] Build plugin validation service
- [ ] Implement dynamic scanner executor loading in orchestration service
- [ ] Create plugin upload UI with Docker image verification
- [ ] Add sandbox environment for testing custom scanners
- [ ] Write plugin development guide for third-party developers

### 📅 Phase 4: Public Marketplace (Q4 2026)
- [ ] Launch public scanner marketplace website
- [ ] Build rating and review system
- [ ] Partner with security vendors for official integrations
- [ ] Implement one-click scanner installation
- [ ] Add scanner recommendation engine based on codebase analysis
- [ ] Create revenue sharing model for premium scanner plugins

---

## Developer Guide: Adding a Scanner Today

Until the marketplace is built, here's the current manual process:

### 1. Add Scanner Metadata (API Service)

**File:** `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

```python
"new-scanner": ScannerMetadata(
    id="new-scanner",
    name="New Scanner",
    description="Brief description shown in UI",
    scanner_type=ScannerType.STATIC_ANALYSIS,
    languages=[ScannerLanguage.SOLIDITY],
    estimated_time_seconds=60,
    requires_compilation=False,
    is_production_ready=True,
    confidence_level="high",
),
```

### 2. Implement Scanner Executor (Orchestration Service)

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/new_scanner.py`

```python
from blocksecops_orchestration.scanners.base import BaseScannerExecutor

class NewScannerExecutor(BaseScannerExecutor):
    def __init__(self):
        super().__init__(
            scanner_id="new-scanner",
            binary_name="new-scanner",
            timeout=60,
            requires_project=True
        )

    def execute(self, target_path: str) -> dict:
        """Run the scanner and return findings"""
        # Implementation here
        pass

    def is_available(self) -> bool:
        """Check if scanner binary is installed"""
        return shutil.which(self.binary_name) is not None
```

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/registry.py`

```python
from blocksecops_orchestration.scanners.new_scanner import NewScannerExecutor

SCANNER_REGISTRY = {
    # ... existing scanners
    "new-scanner": NewScannerExecutor(),
}
```

### 3. Build and Deploy

```bash
# Build API service
cd blocksecops-api-service
docker build -t api-service:0.3.7 .
minikube image load api-service:0.3.7

# Update kustomization
vim k8s/overlays/local/api-service/kustomization.yaml
# Change newTag to 0.3.7

# Deploy
kubectl apply -k k8s/overlays/local/api-service/

# Build orchestration service
cd blocksecops-orchestration
docker build -t blocksecops-orchestration:0.7.7 .
minikube image load blocksecops-orchestration:0.7.7

# Update kustomization
vim k8s/overlays/local/orchestration/kustomization.yaml
# Change newTag to 0.7.7

# Deploy
kubectl apply -k k8s/overlays/local/orchestration/
```

### 4. Verify

```bash
# Check scanner appears in API
curl http://localhost:8000/api/v1/scanners | jq '.scanners[] | select(.id=="new-scanner")'

# Check orchestration recognizes it
curl http://localhost:8004/api/v1/scanners/new-scanner/availability
```

---

## Developer Guide: Removing a Scanner Today

### 1. Remove from API Service

**File:** `blocksecops-api-service/src/infrastructure/scanner_config/scanners.py`

Delete the scanner entry from the `SCANNERS` dictionary.

### 2. Remove from Orchestration Service (Optional)

**File:** `blocksecops-orchestration/src/blocksecops_orchestration/scanners/registry.py`

Remove from `SCANNER_REGISTRY` (optional - leaving it won't break anything).

### 3. Add localStorage Migration (Dashboard)

**File:** `blocksecops-dashboard/src/lib/storage/scannerPreferences.ts`

```typescript
function removeDeprecatedScanner(): void {
  const preferences = getPreferences();
  const defaults = getDefaults();
  let changed = false;

  // Remove from project preferences
  Object.keys(preferences.projects).forEach((projectId) => {
    const project = preferences.projects[projectId];
    const originalLength = project.selectedScanners.length;

    project.selectedScanners = project.selectedScanners.filter(
      (scannerId) => scannerId !== 'deprecated-scanner-id'
    );

    if (project.configs['deprecated-scanner-id']) {
      delete project.configs['deprecated-scanner-id'];
      changed = true;
    }

    if (project.selectedScanners.length !== originalLength) {
      changed = true;
    }
  });

  // Remove from language defaults
  Object.keys(defaults.languages).forEach((language) => {
    const langDefaults = defaults.languages[language];
    const originalLength = langDefaults.selectedScanners.length;

    langDefaults.selectedScanners = langDefaults.selectedScanners.filter(
      (scannerId) => scannerId !== 'deprecated-scanner-id'
    );

    if (langDefaults.selectedScanners.length !== originalLength) {
      changed = true;
    }
  });

  if (changed) {
    setPreferences(preferences);
    setDefaults(defaults);
  }
}

// Call in migratePreferences()
export function migratePreferences(): void {
  removeDeprecatedScanner();
  // ... existing migration code
}
```

### 4. Build and Deploy

Follow the same build/deploy process as adding a scanner (see above).

### 5. Update Documentation

Update these files to reflect the scanner removal:
- `/docs/SCANNER-SELECTION-FEATURE.md`
- `/docs/user-guide/scanner-selection-guide.md`
- `/blocksecops-docs/architecture/phase-4e-scanner-integration-architecture.md`

---

## Competitive Analysis

### Current Market (October 2025)

| Platform | Scanner Model | Customization | Marketplace |
|----------|---------------|---------------|-------------|
| **Mythx** | Fixed set (Mythril, Maru, Harvey) | ❌ No | ❌ No |
| **Slither Cloud** | Single scanner (Slither) | ⚙️ Rule config only | ❌ No |
| **Certora** | Single scanner (Prover) | ⚙️ CVL specs | ❌ No |
| **OpenZeppelin Defender** | Fixed set (Forta, Slither) | ❌ No | ❌ No |
| **Cyfrin Aderyn** | Single scanner (Aderyn) | ❌ No | ❌ No |
| **BlockSecOps (Current)** | Fixed set (20 scanners) | ⚙️ Per-project selection | ❌ No |
| **BlockSecOps (Planned)** | **User-defined + marketplace** | ✅ **Full plugin system** | ✅ **Public marketplace** |

**Key Differentiator:** We will be the **only platform** where users can:
1. Add their own proprietary scanners
2. Install community scanners with one click
3. Build custom security toolchains without vendor lock-in

---

## Business Impact

### Revenue Opportunities
1. **Premium Scanner Subscriptions:** Charge for access to commercial scanners (Certora, Mythril Pro)
2. **Marketplace Commission:** 20% revenue share on paid scanner plugins
3. **Enterprise Custom Scanners:** White-label scanner development for enterprise customers
4. **Scanner-as-a-Service:** Host third-party scanners, charge per-scan usage

### User Acquisition
- **Security Researchers:** Attract researchers who want to integrate their tools
- **Security Vendors:** Partner with scanner developers to reach their customers
- **Enterprise Teams:** Enable companies with internal security tools to use our platform
- **Open Source Community:** Become the de-facto platform for security tool integration

### Competitive Moat
Once users build custom scanner configurations and integrate proprietary tools:
- **High switching costs:** Migrating scanner integrations to competitors is expensive
- **Network effects:** Popular community scanners attract more users
- **Data moat:** Scanner effectiveness ratings create unique dataset

---

## Success Metrics

### Phase 1 (Database Registry)
- **Deployment time reduced:** From 30 minutes (code + build + deploy) to 1 minute (database update)
- **Scanner changes per month:** Track how often we add/remove scanners

### Phase 2 (Marketplace UI)
- **Scanner adoption rate:** % of users who enable 3+ scanners
- **Custom configurations:** # of users who configure scanner-specific settings
- **Scanner diversity:** Average # of unique scanners used per project

### Phase 3 (Plugin Architecture)
- **Custom scanners uploaded:** # of user-added scanner plugins
- **Plugin success rate:** % of uploaded plugins that pass validation
- **Scanner execution volume:** # of custom scanner runs per week

### Phase 4 (Public Marketplace)
- **Marketplace DAU:** Daily active users browsing scanner marketplace
- **Scanner installations:** # of one-click scanner installs
- **Vendor partnerships:** # of official scanner vendor integrations
- **Revenue:** $ generated from premium scanners and marketplace commission

---

## Security & Compliance Considerations

### Scanner Isolation
- Run all scanners in isolated Docker containers
- Enforce CPU/memory limits per scanner execution
- Network isolation: Scanners cannot access external services without explicit permission

### Code Scanning Safety
- Scanner containers have read-only access to user code
- All scanner output is sanitized before storage
- Malicious output cannot trigger XSS or code injection

### Plugin Verification
- **Option 1:** Require code signing for community scanners
- **Option 2:** Allowlist trusted Docker registries (Docker Hub, GHCR, vendor registries)
- **Option 3:** Sandbox new scanners in test environment before production approval

### Compliance
- **SOC 2:** Scanner execution logs for audit trail
- **GDPR:** User control over scanner data retention
- **ISO 27001:** Scanner vulnerability scanning and patching process

---

## Next Steps

1. **Review this document** with product and engineering teams
2. **Prioritize Phase 1** for Q1 2026 roadmap
3. **Create Figma mockups** for marketplace UI
4. **Draft scanner plugin specification** with example YAML
5. **Identify launch partners** (Trail of Bits, Cyfrin, Consensys) for early marketplace

---

## References

- [SCANNER-SYNCHRONIZATION-STATUS.md](/Users/pwner/Git/ABS/docs/SCANNER-SYNCHRONIZATION-STATUS.md) - Current scanner architecture
- [SCANNER-SELECTION-FEATURE.md](/Users/pwner/Git/ABS/docs/SCANNER-SELECTION-FEATURE.md) - Scanner selection UI implementation
- [phase-4e-scanner-integration-architecture.md](/Users/pwner/Git/ABS/blocksecops-docs/architecture/phase-4e-scanner-integration-architecture.md) - Scanner execution architecture

---

**Document Owner:** Engineering Team
**Last Updated:** October 21, 2025
**Next Review:** Q1 2026 Planning
