# Scanner Selection Feature - User Guide

**Version**: 1.0
**Last Updated**: October 18, 2025
**Feature Status**: ✅ Complete (Phase 3, Week 6 Day 3)

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Feature Capabilities](#feature-capabilities)
4. [User Interface Guide](#user-interface-guide)
5. [Scanner Presets](#scanner-presets)
6. [Scanner Configuration](#scanner-configuration)
7. [Preferences and Persistence](#preferences-and-persistence)
8. [Technical Reference](#technical-reference)
9. [Best Practices](#best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The Scanner Selection feature allows users to customize which security scanners run for each smart contract, providing fine-grained control over security analysis depth, scan time, and resource usage.

### Key Benefits

- **Flexibility**: Choose exactly which scanners to run per contract
- **Time Control**: See estimated scan time before triggering
- **Cost Efficiency**: Run only the scanners you need
- **Smart Defaults**: Use presets for quick/standard/deep scans
- **Customization**: Configure scanner-specific options (e.g., Echidna iterations)
- **Persistence**: Your preferences are saved per project

### Supported Languages

- **Solidity** - Ethereum smart contracts
- **Vyper** - Alternative Ethereum language
- **Rust** - Solana/Substrate programs
- **Move** - Aptos/Sui smart contracts

---

## Quick Start

### Basic Workflow

1. **Navigate to Contract Details** - Click on any contract in your project
2. **Click "Run Security Scan"** - Opens scanner selection modal
3. **Select Scanners** - Choose from available scanners or use a preset
4. **Review Estimated Time** - See how long the scan will take
5. **Start Scan** - Click "Start Scan" button

### Using Presets (Recommended)

The fastest way to get started:

1. Open scanner selection modal
2. Click one of the preset buttons:
   - **Quick Scan** (~30 seconds) - Fast static analysis only
   - **Standard Scan** (~5 minutes) - Balanced coverage
   - **Deep Scan** (~15 minutes) - Comprehensive analysis
3. Click "Start Scan"

Your selection is automatically saved for next time!

---

## Feature Capabilities

### 1. Language-Specific Filtering

Scanners are automatically filtered based on your contract's detected language. Only compatible scanners are shown.

**Example**:
- Solidity contracts see: Slither, Mythril, Echidna, etc.
- Rust contracts see: cargo-audit, cargo-clippy, etc.

### 2. Category Grouping

Scanners are organized into 5 categories for easy navigation:

| Category | Description | Typical Time | Example Tools |
|----------|-------------|--------------|---------------|
| **Static Analysis** 🔍 | Code analysis without execution | ~30 seconds | Slither, Semgrep |
| **Fuzzing** 🎲 | Property-based testing with random inputs | ~5 minutes | Echidna, Foundry |
| **Symbolic Execution** 🧮 | Path exploration and constraint solving | ~10 minutes | Mythril |
| **Formal Verification** ✓ | Mathematical proof of correctness | ~15 minutes | Certora, K Framework |
| **Linting** 📝 | Style and best practice checks | ~10 seconds | Solhint, cargo-clippy |

### 3. Scanner Metadata

Each scanner displays helpful information:

- **Name and Version** - e.g., "Slither v0.10.0"
- **Developer** - Who maintains the tool
- **Description** - What the scanner does
- **Estimated Time** - How long it takes to run
- **Production Status** - Badge for production-ready tools
- **Compilation Required** - Warning if contract must compile first
- **Configure Button** - For scanners with options (see below)

### 4. Selection Controls

- **Checkboxes** - Click any scanner to toggle selection
- **Select All** - Select all scanners in current view
- **Clear All** - Deselect all scanners
- **Preset Buttons** - Quick selection for quick/standard/deep scans

### 5. Real-Time Estimated Time

As you select/deselect scanners, the total estimated time updates automatically:

```
Selected: 5 scanners
Estimated time: 6 minutes 45 seconds
```

This helps you balance thoroughness vs. speed.

---

## User Interface Guide

### Scanner Selection Modal

```
┌─────────────────────────────────────────────────────────┐
│ Configure Security Scan                            [X]  │
│ Select scanners and configure options for MyContract   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Scan Presets:                                          │
│ [ Quick Scan ] [ Standard Scan ] [ Deep Scan ]         │
│                                                         │
│ [ Select All ]  [ Clear All ]                          │
│                                                         │
│ Static Analysis 🔍                                      │
│ Fast code analysis without execution (~30s)            │
│ ┌─────────────────────────────────────────────────┐   │
│ │ [✓] Slither v0.10.0                             │   │
│ │     Trail of Bits - Production Ready            │   │
│ │     Static analysis for Solidity                │   │
│ │     Est. time: 30 seconds                       │   │
│ │                                                  │   │
│ │ [✓] Semgrep v1.45.0              [Configure]    │   │
│ │     r2c - Production Ready                      │   │
│ │     Pattern-based static analysis               │   │
│ │     Est. time: 20 seconds                       │   │
│ └─────────────────────────────────────────────────┘   │
│                                                         │
│ Fuzzing 🎲                                              │
│ Property-based testing with random inputs (~5 min)     │
│ ┌─────────────────────────────────────────────────┐   │
│ │ [✓] Echidna v2.2.1              [Configure]     │   │
│ │     Trail of Bits - Production Ready            │   │
│ │     Smart contract fuzzer                       │   │
│ │     Est. time: 5 minutes                        │   │
│ └─────────────────────────────────────────────────┘   │
│                                                         │
│ ... (more categories)                                  │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ Selected: 5 scanners                                   │
│ Estimated time: 6 minutes 45 seconds                   │
│                                                         │
│                    [Cancel]  [Start Scan]              │
└─────────────────────────────────────────────────────────┘
```

### Scanner Configuration Modal

When you click "Configure" on a scanner with options:

```
┌─────────────────────────────────────────────────────────┐
│ Configure Scanner: Echidna                        [X]  │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ Test Limit                                             │
│ Maximum number of test iterations                      │
│ ┌─────────────────┐                                    │
│ │ 50000           │  (default: 50000, range: 1-1000000)│
│ └─────────────────┘                                    │
│                                                         │
│ Timeout (seconds)                                      │
│ Maximum execution time per test                        │
│ ┌─────────────────┐                                    │
│ │ 300             │  (default: 300, range: 10-3600)   │
│ └─────────────────┘                                    │
│                                                         │
│ Coverage Guided                                        │
│ Use coverage-guided fuzzing                            │
│ ☑ Enabled                                              │
│                                                         │
│                                                         │
│      [Reset to Defaults]  [Cancel]  [Save]            │
└─────────────────────────────────────────────────────────┘
```

---

## Scanner Presets

Presets are recommended scanner combinations optimized for different use cases.

### Quick Scan (~30 seconds)

**Purpose**: Fast feedback for development workflow

**Scanners Included**:
- Slither (static analysis)
- Solhint (linting)

**Best For**:
- Pre-commit checks
- Rapid iteration during development
- Quick sanity checks

**Limitations**:
- Only catches obvious issues
- No deep analysis
- May miss complex vulnerabilities

### Standard Scan (~5 minutes)

**Purpose**: Balanced security analysis for most contracts

**Scanners Included**:
- Slither (static analysis)
- Semgrep (pattern matching)
- Echidna (fuzzing)
- Solhint (linting)

**Best For**:
- Regular security checks
- Pre-deployment validation
- Pull request verification

**Coverage**:
- Common vulnerabilities (reentrancy, overflow, etc.)
- Best practice violations
- Property-based testing

### Deep Scan (~15 minutes)

**Purpose**: Comprehensive security audit before mainnet deployment

**Scanners Included**:
- All Static Analysis tools
- All Fuzzing tools
- Symbolic Execution (Mythril)
- Formal Verification (where available)
- All Linters

**Best For**:
- Pre-mainnet audits
- High-value contracts
- Critical infrastructure
- Compliance requirements

**Coverage**:
- All vulnerability classes
- Complex attack vectors
- Mathematical verification
- Comprehensive property testing

### Custom Selection

Choose your own scanner combination for specific needs:

**Examples**:
- **Fuzzing Focus**: Echidna + Foundry + Harvey
- **Static Only**: Slither + Semgrep + Solhint
- **Quick + Fuzz**: Slither + Echidna (fast + some depth)

---

## Scanner Configuration

Many scanners support configuration options to customize their behavior.

### Configurable Scanners

| Scanner | Configurable Options | Common Use Cases |
|---------|---------------------|------------------|
| **Echidna** | Test limit, timeout, coverage-guided, corpus directory | Increase iterations for complex properties |
| **Semgrep** | Rule sets, severity threshold | Enable/disable specific rule categories |
| **Mythril** | Max depth, solver timeout, execution timeout | Adjust for contract complexity |
| **Slither** | Detectors to exclude, optimization level | Skip known false positives |

### Configuration Workflow

1. **Open Scanner Selection** - Click "Run Security Scan"
2. **Find Configurable Scanner** - Look for "Configure" button
3. **Click Configure** - Opens configuration modal
4. **Adjust Settings** - Modify options as needed
5. **Save** - Configuration is automatically persisted
6. **Start Scan** - Scan runs with your custom settings

### Option Types

**Number Inputs** (e.g., test iterations):
- Min/max validation
- Default value shown
- Real-time error checking

**String Inputs** (e.g., corpus directory):
- Free-form text
- Path validation where applicable

**Boolean Toggles** (e.g., coverage-guided):
- On/off checkbox
- Default state shown

**Select Dropdowns** (e.g., rule sets):
- Predefined options
- Single or multiple selection

### Reset to Defaults

Click "Reset to Defaults" in any configuration modal to restore scanner default values.

---

## Preferences and Persistence

Your scanner selections and configurations are automatically saved.

### Per-Project Preferences

Each project (contract) has its own saved preferences:

- **Selected Scanners** - Which scanners you last chose
- **Scanner Configs** - Custom options for each scanner
- **Last Updated** - Timestamp of last change

**Storage Location**: Browser LocalStorage (persists across sessions)

### Auto-Load Behavior

When you open scanner selection for a contract:

1. System checks if preferences exist for this project
2. If found, scanners are pre-selected with saved configs
3. If not found, shows default state (no selection)

This saves time on repeated scans!

### Per-Language Defaults (Future)

Future enhancement will allow setting default scanner selections per language:

- Set your preferred Solidity scanners once
- Auto-apply to all new Solidity contracts
- Override per-project as needed

### Preferences Management

**Export Preferences** (Future):
```typescript
import { exportPreferences } from '@/lib/storage/scannerPreferences';
const backup = exportPreferences();
// Save to file for backup
```

**Import Preferences** (Future):
```typescript
import { importPreferences } from '@/lib/storage/scannerPreferences';
importPreferences(backupJson);
```

**Clear Preferences**:
```typescript
import { clearProjectPreferences } from '@/lib/storage/scannerPreferences';
clearProjectPreferences(projectId);
```

---

## Technical Reference

### API Integration

Scanner selection integrates with existing API endpoints:

**List Scanners** (language-filtered):
```typescript
GET /api/v1/scanners?language=solidity
```

**Get Scanner Details**:
```typescript
GET /api/v1/scanners/{scanner_id}
```

**Get Presets**:
```typescript
GET /api/v1/scanners/presets/solidity
GET /api/v1/scanners/presets/solidity/standard
```

**Create Scan with Selected Scanners**:
```typescript
POST /api/v1/scans
{
  "contract_id": "uuid",
  "scan_type": "full",
  "scanner_ids": ["scanner-uuid-1", "scanner-uuid-2"],
  "scanner_configs": {
    "scanner-uuid-1": {
      "test_limit": 50000,
      "timeout": 300
    }
  }
}
```

### Component Architecture

```
ContractDetail.tsx (Page)
  └─> ScannerSelector (Selection UI)
       ├─> Uses: listScanners() API
       ├─> Uses: getScannerPresets() API
       └─> Triggers: onConfigureScanner()

  └─> ScannerConfigModal (Configuration UI)
       ├─> Uses: getScannerById() API
       └─> Callbacks: onSave(scannerId, config)

  └─> scannerPreferences (Storage)
       ├─> getProjectPreferences(projectId)
       ├─> saveProjectPreferences(projectId, scanners, configs)
       └─> saveScannerConfig(projectId, scannerId, config)
```

### Storage Schema

```typescript
// LocalStorage key: blocksecops_scanner_preferences
{
  version: 1,
  projects: {
    "project-uuid": {
      selectedScanners: ["scanner-1", "scanner-2"],
      configs: {
        "scanner-1": { test_limit: 50000 },
        "scanner-2": { timeout: 300 }
      },
      lastUpdated: "2025-10-18T12:00:00Z"
    }
  }
}

// LocalStorage key: blocksecops_scanner_defaults
{
  version: 1,
  languages: {
    "solidity": {
      selectedScanners: ["scanner-1", "scanner-2"],
      lastUpdated: "2025-10-18T12:00:00Z"
    }
  }
}
```

### TypeScript Interfaces

```typescript
interface Scanner {
  id: string;
  name: string;
  version: string;
  category: ScannerCategory;
  languages: ScannerLanguage[];
  description: string;
  developer: string;
  estimated_time_seconds: number;
  requires_compilation: boolean;
  is_production_ready: boolean;
  configurable_options?: ScannerOption[];
}

interface ScannerOption {
  name: string;
  type: 'number' | 'string' | 'boolean' | 'select';
  description: string;
  default: any;
  min?: number;
  max?: number;
  options?: string[];
}

type ScannerCategory =
  | 'static_analysis'
  | 'fuzzing'
  | 'symbolic_execution'
  | 'formal_verification'
  | 'linting';

type ScannerLanguage =
  | 'solidity'
  | 'vyper'
  | 'rust'
  | 'move';
```

---

## Best Practices

### 1. Development Workflow

**During Development**:
- Use **Quick Scan** for fast feedback
- Run on every significant code change
- Focus on static analysis + linting

**Before Committing**:
- Use **Standard Scan** for PR validation
- Review all findings before pushing
- Configure CI/CD to run Standard Scan

**Pre-Deployment**:
- Use **Deep Scan** before mainnet
- Allow full execution time (15+ minutes)
- Review all findings with team

### 2. Scanner Selection Strategy

**Start Broad, Then Focus**:
1. Run Deep Scan once to find all issues
2. Fix critical/high issues
3. Run targeted scans (e.g., fuzzing only) during iteration
4. Run Deep Scan again before final deployment

**Layer Your Defense**:
- Static Analysis (fast, catches obvious issues)
- + Fuzzing (moderate time, property testing)
- + Symbolic Execution (deep, path exploration)
- + Formal Verification (deepest, mathematical proof)

### 3. Configuration Tips

**Echidna (Fuzzer)**:
- Default: 50,000 iterations (good for most cases)
- Complex properties: Increase to 100,000-500,000
- Time-constrained: Decrease to 10,000-25,000

**Mythril (Symbolic Execution)**:
- Default: 300s timeout (5 minutes)
- Large contracts: Increase to 600-900s
- Quick checks: Decrease to 120s

### 4. Resource Management

**Time Budgets**:
- Dev iteration: Budget 1-2 minutes (Quick Scan)
- PR validation: Budget 5-10 minutes (Standard Scan)
- Pre-deployment: Budget 30-60 minutes (Deep Scan + review)

**Cost Optimization**:
- Don't run Deep Scan on every commit
- Use Quick Scan for rapid iteration
- Reserve expensive scanners for critical checkpoints

### 5. Interpreting Results

**After Scan Completes**:
1. Review scan status in contract detail page
2. Check vulnerability counts by severity
3. Click into each finding for details
4. Use "Export Report" for offline review
5. Track fixes and re-scan

**Priority Order**:
1. Critical vulnerabilities (exploit possible)
2. High vulnerabilities (security risk)
3. Medium vulnerabilities (best practice)
4. Low vulnerabilities (informational)

---

## Troubleshooting

### Scanner Selection Issues

**Problem**: No scanners appear in list

**Solutions**:
- Check that contract has detected language
- Verify API connection (network tab)
- Try refreshing the page
- Check browser console for errors

---

**Problem**: Preset buttons don't work

**Solutions**:
- Check network connectivity
- Verify preset API endpoint is available
- Try manual scanner selection instead
- Check browser console for API errors

---

**Problem**: Configuration modal doesn't open

**Solutions**:
- Ensure scanner has `configurable_options` defined
- Check browser console for errors
- Try clearing browser cache
- Verify scanner details API is working

---

### Scan Execution Issues

**Problem**: Scan fails to start

**Solutions**:
- Ensure at least one scanner is selected
- Check that selected scanners support contract language
- Verify API authentication token is valid
- Check network connectivity

---

**Problem**: Scan takes longer than estimated

**Solutions**:
- Estimated times are approximate
- Complex contracts may take longer
- Reduce scanner count or adjust configs
- Consider splitting into multiple scans

---

**Problem**: Configuration not saved

**Solutions**:
- Check browser LocalStorage is enabled
- Verify no browser privacy mode active
- Check storage quota not exceeded
- Try exporting preferences as backup

---

### Preferences Issues

**Problem**: Preferences not loading

**Solutions**:
- Check browser LocalStorage enabled
- Verify correct project ID
- Try clearing and re-saving preferences
- Check storage schema version (auto-migrates)

---

**Problem**: Preferences lost after browser close

**Solutions**:
- Ensure browser not in private/incognito mode
- Check browser settings allow persistent storage
- Verify LocalStorage not being cleared by extensions
- Use export/import as backup

---

### Common Error Messages

**"No scanners available for this language"**
- Language not yet supported
- Check contract language detection
- Contact support if language should be supported

**"Scanner configuration invalid"**
- Check option values are within min/max range
- Verify required fields are filled
- Reset to defaults and try again

**"Failed to create scan"**
- Check network connectivity
- Verify authentication token
- Ensure contract ID is valid
- Check API service status

---

## Related Documentation

- **Scanner API Reference**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/lib/api/scanners.ts`
- **Scan API Reference**: `/Users/pwner/Git/ABS/blocksecops-dashboard/src/lib/api/scans.ts`
- **Implementation Status**: `/Users/pwner/Git/ABS/docs/SCANNER-SELECTION-IMPLEMENTATION-STATUS.md`
- **Phase 3 Progress**: `/Users/pwner/Git/ABS/docs/PHASE-3-PROGRESS-TRACKER.md`
- **Platform Standards**: `/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md`

---

## Support

For questions, issues, or feature requests:

1. Check this documentation first
2. Review implementation status document
3. Search existing GitHub issues
4. Create new issue with:
   - What you were trying to do
   - What happened instead
   - Browser console errors (if any)
   - Steps to reproduce

---

**Version History**:
- v1.0 (Oct 18, 2025) - Initial release with scanner selection, configuration, and preferences
