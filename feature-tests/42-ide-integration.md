# Feature Test: IDE Integration

**Feature**: IDE Integration (VS Code, JetBrains, Neovim)
**Version**: 1.0.0
**Last Updated**: January 19, 2026
**Status**: Partially Implemented

## Implementation Status

| Component | Status | Notes |
|-----------|--------|-------|
| API scan_source field | ✅ Tested | API v0.11.2 - stores and returns scan_source |
| API scan_source filter | ✅ Tested | `?scan_source=vscode` filtering works |
| Dashboard ScanSourceBadge | ✅ Tested | Dashboard v0.30.12 - badges display correctly |
| CLI --local flag | ⏳ Pending | Code created, needs testing |
| VS Code extension | ⏳ Pending | Code created, needs build and install |
| JetBrains plugin | ⏳ Pending | Code created, needs build and install |
| Neovim plugin | ⏳ Pending | Code created, needs testing |

## Prerequisites

- [ ] blocksecops-cli installed: `pip install blocksecops-cli`
- [ ] API key configured: `blocksecops auth login`
- [ ] SolidityDefend available (auto-downloads on first use)
- [ ] Test Solidity files available

---

## 1. CLI Local Scanning

### TC-42-001: Local Scan with SolidityDefend

**Steps**:
1. Run `blocksecops scan run test.sol --local`
2. Verify SolidityDefend downloads if not present
3. Verify scan completes and results display
4. Verify scan appears in dashboard

**Expected**:
- SolidityDefend binary at `~/.blocksecops/bin/soliditydefend`
- Scan results in JSON format
- Scan visible in dashboard with source badge

**Status**: [ ]

### TC-42-002: Scan Source Parameter

**Steps**:
1. Run `blocksecops scan run test.sol --local --scan-source vscode`
2. Check scan in dashboard
3. Verify source badge shows "VS Code"

**Expected**:
- `scan_source` field = "vscode"
- Dashboard shows VS Code badge with icon

**Status**: [ ]

### TC-42-003: SolidityDefend Auto-Update

**Steps**:
1. Delete `~/.blocksecops/bin/.version`
2. Run local scan
3. Verify latest version downloaded

**Expected**:
- Version file updated with latest tag
- Binary replaced with latest release

**Status**: [ ]

---

## 2. VS Code Extension

### TC-42-010: Extension Installation

**Steps**:
1. Install extension from VSIX
2. Reload VS Code
3. Verify extension active (check Extension Host output)

**Expected**:
- Extension loads without errors
- Commands available in Command Palette

**Status**: [ ]

### TC-42-011: API Key Configuration

**Steps**:
1. Open Settings (Cmd+,)
2. Search "blocksecops"
3. Enter API key
4. Save and reload

**Expected**:
- API key stored in VS Code settings
- No plaintext in logs

**Status**: [ ]

### TC-42-012: Manual Scan Command

**Steps**:
1. Open a `.sol` file
2. Run command: "BlockSecOps: Scan Current File"
3. Wait for scan to complete

**Expected**:
- Progress notification shown
- Results appear in Problems panel
- Inline diagnostics in editor

**Status**: [ ]

### TC-42-013: Scan on Save

**Steps**:
1. Enable `blocksecops.scanOnSave` setting
2. Open a `.sol` file
3. Make a change and save

**Expected**:
- Scan triggers automatically on save
- Previous diagnostics cleared
- New diagnostics appear

**Status**: [ ]

### TC-42-014: Diagnostic Severity Mapping

**Steps**:
1. Scan a contract with mixed severity vulnerabilities
2. Check Problems panel
3. Verify severity icons

**Expected**:
- Critical/High: Error (red)
- Medium: Warning (yellow)
- Low/Info: Information (blue)

**Status**: [ ]

### TC-42-015: Dashboard Link

**Steps**:
1. Scan a contract
2. Click vulnerability in Problems panel
3. Right-click > "View in BlockSecOps Dashboard"

**Expected**:
- Browser opens to scan detail page

**Status**: [ ]

---

## 3. JetBrains Plugin

### TC-42-020: Plugin Installation

**Steps**:
1. Install plugin from ZIP
2. Restart IDE
3. Verify plugin listed in Settings > Plugins

**Expected**:
- Plugin loads without errors
- Settings page available

**Status**: [ ]

### TC-42-021: Settings Configuration

**Steps**:
1. Open Settings > Tools > BlockSecOps
2. Enter API key
3. Configure CLI path (or leave blank for auto-detect)
4. Apply settings

**Expected**:
- Settings persist across restarts
- CLI path resolved correctly

**Status**: [ ]

### TC-42-022: External Annotator

**Steps**:
1. Open a `.sol` file
2. Wait for external annotator to run
3. Check for inline annotations

**Expected**:
- Gutter icons for vulnerabilities
- Hover shows vulnerability details
- Severity colors match

**Status**: [ ]

### TC-42-023: Inspection Results

**Steps**:
1. Run Analyze > Inspect Code
2. Select Solidity files
3. Review inspection results

**Expected**:
- BlockSecOps findings in inspection results
- Double-click navigates to line

**Status**: [ ]

### TC-42-024: Background Analysis

**Steps**:
1. Open project with multiple `.sol` files
2. Verify background analysis runs
3. Check indexing progress

**Expected**:
- Non-blocking analysis
- Results update as files are processed

**Status**: [ ]

---

## 4. Neovim Plugin

### TC-42-030: Plugin Installation

**Steps**:
1. Add plugin to lazy.nvim/packer config
2. Run `:Lazy sync` or `:PackerSync`
3. Verify no errors

**Expected**:
- Plugin loads cleanly
- `:BlockSecOps*` commands available

**Status**: [ ]

### TC-42-031: Setup Configuration

**Steps**:
```lua
require('blocksecops').setup({
  api_key = os.getenv('BLOCKSECOPS_API_KEY'),
  scan_on_save = true,
})
```
2. Open Neovim
3. Verify setup runs without errors

**Expected**:
- Configuration accepted
- Autocommands registered

**Status**: [ ]

### TC-42-032: Manual Scan

**Steps**:
1. Open a `.sol` file
2. Run `:BlockSecOpsScan`
3. Wait for results

**Expected**:
- Scan progress shown in cmdline
- Diagnostics appear in buffer

**Status**: [ ]

### TC-42-033: Diagnostic Display

**Steps**:
1. Scan a contract with vulnerabilities
2. Check inline virtual text
3. Check sign column

**Expected**:
- Virtual text shows vulnerability title
- Signs show severity icons

**Status**: [ ]

### TC-42-034: Scan on Save

**Steps**:
1. Enable `scan_on_save = true`
2. Open a `.sol` file
3. Make a change and `:w`

**Expected**:
- Scan triggers on BufWritePost
- Diagnostics update

**Status**: [ ]

### TC-42-035: Quickfix List

**Steps**:
1. Scan a contract
2. Run `:BlockSecOpsQuickfix`
3. Navigate with `:cnext`/`:cprev`

**Expected**:
- All vulnerabilities in quickfix list
- Navigation jumps to correct lines

**Status**: [ ]

---

## 5. Dashboard Integration

### TC-42-040: Scan Source Badge Display

**Steps**:
1. Create scans from different sources (web, cli, vscode)
2. View scans in dashboard
3. Check Source column

**Expected**:
- Badges with correct icons
- Color coding matches source

**Status**: [ ]

### TC-42-041: Scan Source Filter

**Steps**:
1. Go to Scans page
2. Click Source filter dropdown
3. Select "VS Code"

**Expected**:
- Only VS Code scans shown
- Filter persists on refresh

**Status**: [ ]

### TC-42-042: API scan_source Field

**Steps**:
1. Call `GET /api/v1/scans`
2. Check response includes `scan_source`
3. Call `GET /api/v1/scans?scan_source=cli`

**Expected**:
- `scan_source` in response
- Filter works correctly

**Status**: [ ]

---

## 6. Vim 8+ ALE Integration

### TC-42-050: ALE Linter Registration

**Steps**:
1. Add to `.vimrc`:
```vim
let g:ale_linters = { 'solidity': ['blocksecops'] }
```
2. Open a `.sol` file
3. Verify linter runs

**Expected**:
- ALE shows BlockSecOps in linter list
- Diagnostics appear

**Status**: [ ]

### TC-42-051: Async Linting

**Steps**:
1. Open large Solidity project
2. Verify linting doesn't block editing

**Expected**:
- Editor remains responsive
- Results appear asynchronously

**Status**: [ ]

---

## 7. Error Handling

### TC-42-060: No API Key

**Steps**:
1. Remove API key from configuration
2. Attempt to scan

**Expected**:
- Clear error message: "API key not configured"
- Link to documentation

**Status**: [ ]

### TC-42-061: Network Failure

**Steps**:
1. Disconnect from network
2. Run local scan

**Expected**:
- Local scan succeeds
- Warning about sync failure
- Results saved for later sync

**Status**: [ ]

### TC-42-062: Invalid Contract

**Steps**:
1. Open non-Solidity file
2. Attempt scan

**Expected**:
- Error: "Not a Solidity file"
- No crash or hang

**Status**: [ ]

---

## Test Notes

```
[Date] | [Tester] | [Test ID] | [Result] | [Notes]
2026-01-19 | Claude Code | TC-42-040-042 | PASS | API scan_source tested (v0.11.2): create, store, filter all working
2026-01-19 | Claude Code | ScanSourceBadge | PASS | Dashboard badges display correctly (v0.30.12)
2026-01-19 | Claude Code | TC-42-001-039 | PENDING | CLI and IDE plugins created but not yet tested
```
