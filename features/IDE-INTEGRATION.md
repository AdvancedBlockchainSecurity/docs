# IDE Integration Feature

**Version:** 1.0.0
**Last Updated:** January 19, 2026
**Status:** Partially Implemented
**Phase:** IDE Integration

## Implementation Status

| Component | Status | Version |
|-----------|--------|---------|
| API scan_source field | ✅ Tested | v0.11.2 |
| Dashboard ScanSourceBadge | ✅ Tested | v0.30.12 |
| CLI --local flag | ⏳ Created, not tested | - |
| CLI --scan-source flag | ⏳ Created, not tested | - |
| VS Code extension | ⏳ Created, not tested | - |
| JetBrains plugin | ⏳ Created, not tested | - |
| Neovim plugin | ⏳ Created, not tested | - |

## Overview

IDE integrations bring Apogee security scanning directly into developer workflows through VS Code, JetBrains (IntelliJ/WebStorm), and Vim/Neovim plugins. All integrations use the `0xapogee-cli` tool with local SolidityDefend scanning.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer Workflow                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐   ┌──────────────┐   ┌──────────────┐            │
│  │ VS Code  │   │  JetBrains   │   │ Vim/Neovim   │            │
│  │Extension │   │   Plugin     │   │   Plugin     │            │
│  └────┬─────┘   └──────┬───────┘   └──────┬───────┘            │
│       │                │                  │                     │
│       └────────────────┼──────────────────┘                     │
│                        │                                        │
│                        ▼                                        │
│              ┌─────────────────┐                                │
│              │ 0xapogee-cli │                                │
│              │  --local flag   │                                │
│              │  --scan-source  │                                │
│              └────────┬────────┘                                │
│                       │                                         │
│         ┌─────────────┼─────────────┐                          │
│         │             │             │                          │
│         ▼             ▼             ▼                          │
│  ┌────────────┐ ┌───────────┐ ┌──────────────┐                 │
│  │SolidityDef │ │ BlockSec  │ │  Dashboard   │                 │
│  │   (local)  │ │ API Sync  │ │ (scan_source │                 │
│  │            │ │           │ │   badges)    │                 │
│  └────────────┘ └───────────┘ └──────────────┘                 │
└─────────────────────────────────────────────────────────────────┘
```

## Key Features

### 1. Local Scanning with SolidityDefend

- Auto-downloads latest SolidityDefend from GitHub releases
- Runs locally for fast feedback (no network latency for scanning)
- Results synced to Apogee API for dashboard visibility

### 2. Scan Source Tracking

Each scan records its origin for analytics and filtering:

| Source | Description |
|--------|-------------|
| `web` | Dashboard web interface |
| `cli` | Command-line tool directly |
| `vscode` | VS Code extension |
| `jetbrains` | IntelliJ/WebStorm plugin |
| `neovim` | Neovim Lua plugin |
| `vim` | Vim 8+ ALE linter |
| `github_actions` | GitHub Actions CI/CD |
| `gitlab_ci` | GitLab CI pipeline |

### 3. IDE-Specific Features

| Feature | VS Code | JetBrains | Neovim |
|---------|---------|-----------|--------|
| Inline diagnostics | Yes | Yes | Yes |
| Severity icons | Yes | Yes | Yes |
| Quick fixes | Planned | Planned | No |
| Scan on save | Yes | Yes | Yes |
| Manual scan command | Yes | Yes | Yes |
| Dashboard link | Yes | Yes | Yes |

## CLI Enhancements

### New Flags

```bash
# Local scanning with SolidityDefend
0xapogee scan run contract.sol --local

# Specify scan source
0xapogee scan run contract.sol --local --scan-source vscode

# Full example
0xapogee scan run ./contracts/ --local --scan-source jetbrains --output json
```

### CLI Workflow

1. Check API connection (requires authentication)
2. Download/update SolidityDefend from GitHub if needed
3. Create contract via API: `POST /contracts`
4. Create scan via API: `POST /scans` (with `scan_source`)
5. Run SolidityDefend locally
6. Transform results to API format
7. Submit results: `POST /scans/{id}/results`
8. Display formatted output

## Database Changes

### Migration 034: Add scan_source Field

```sql
ALTER TABLE scans ADD COLUMN scan_source VARCHAR(50) NOT NULL DEFAULT 'web';
CREATE INDEX idx_scans_scan_source ON scans(scan_source);
```

## Dashboard Changes

### ScanSourceBadge Component

New component displays scan origin with icons:

```typescript
const sourceConfig = {
  web: { label: 'Web', bg: 'bg-blue-100', icon: GlobeIcon },
  cli: { label: 'CLI', bg: 'bg-gray-100', icon: TerminalIcon },
  vscode: { label: 'VS Code', bg: 'bg-sky-100', icon: VSCodeIcon },
  jetbrains: { label: 'JetBrains', bg: 'bg-purple-100', icon: JetBrainsIcon },
  neovim: { label: 'Neovim', bg: 'bg-green-100', icon: NeovimIcon },
  github_actions: { label: 'GitHub Actions', bg: 'bg-gray-800', icon: GitHubIcon },
};
```

### Scan List Table

- Added "Source" column with ScanSourceBadge
- Filter dropdown for scan source

## IDE Repositories

| Repository | Language | Status |
|------------|----------|--------|
| `blocksecops-vscode` | TypeScript | Complete |
| `blocksecops-intellij` | Kotlin | Complete |
| `blocksecops-nvim` | Lua | Complete |

## Installation

### VS Code

```bash
# From marketplace (when published)
code --install-extension blocksecops.0xapogee-vscode

# From VSIX
code --install-extension blocksecops-vscode-1.0.0.vsix
```

### JetBrains

1. Settings > Plugins > Install from disk
2. Select `blocksecops-intellij-1.0.0.zip`
3. Restart IDE

### Neovim

```lua
-- Using lazy.nvim
{
  'blocksecops/blocksecops-nvim',
  config = function()
    require('blocksecops').setup({
      api_key = os.getenv('APOGEE_API_KEY'),
      scan_on_save = true,
    })
  end
}
```

### Vim (ALE)

```vim
" Enable Apogee linter for Solidity
let g:ale_linters = { 'solidity': ['blocksecops'] }
```

## Configuration

### VS Code Settings

```json
{
  "blocksecops.apiKey": "your-api-key",
  "blocksecops.cliPath": "blocksecops",
  "blocksecops.scanOnSave": true,
  "blocksecops.showSeverities": ["critical", "high", "medium"]
}
```

### JetBrains Settings

Settings > Tools > Apogee:
- API Key
- CLI Path (default: auto-detect)
- Scan on Save
- Severity Filter

### Neovim Configuration

```lua
require('blocksecops').setup({
  api_key = os.getenv('APOGEE_API_KEY'),
  cli_path = nil,  -- auto-detect
  scan_on_save = true,
  virtual_text = true,
  signs = true,
  severity_filter = { 'critical', 'high', 'medium' },
})
```

## Related Documentation

- **CLI Documentation**: `/blocksecops-docs/integrations/cli/`
- **API Reference**: `/blocksecops-docs/api/`
- **Test Checklist**: `/docs/feature-tests/42-ide-integration.md`
- **Database Migration**: `/docs/database/MIGRATIONS.md` (Migration 034)
- **Task Documentation**: `/TaskDocs-Apogee/phases/06-phase-ide-integration/`
