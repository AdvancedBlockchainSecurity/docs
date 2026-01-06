# 35. CLI Tool (blocksecops-cli)

Test the BlockSecOps command-line interface tool.

---

## Prerequisites

- [ ] Python 3.10+ installed
- [ ] pip/pipx available
- [ ] Valid BlockSecOps API key
- [ ] Sample Solidity contract file

---

## 1. Installation

### 1.1 Install via pip

```bash
pip install blocksecops-cli
```

- [ ] Package installs without errors
- [ ] All dependencies resolved
- [ ] `blocksecops` command available

---

### 1.2 Install via pipx (isolated)

```bash
pipx install blocksecops-cli
```

- [ ] Package installs in isolated environment
- [ ] `blocksecops` command available

---

### 1.3 Install from source

```bash
git clone https://github.com/blocksecops/blocksecops-cli
cd blocksecops-cli
pip install -e .
```

- [ ] Editable install succeeds
- [ ] `blocksecops` command available

---

## 2. Authentication Commands

### 2.1 Login

```bash
blocksecops auth login
```

- [ ] Prompts for API key
- [ ] Validates key against API
- [ ] Stores key in keyring/config
- [ ] Shows success message

---

### 2.2 Login with Key Flag

```bash
blocksecops auth login --api-key bso_live_xxx
```

- [ ] Accepts key from flag
- [ ] No interactive prompt
- [ ] Validates and stores key

---

### 2.3 Login with Custom URL

```bash
blocksecops auth login --api-url http://localhost:8000
```

- [ ] Saves custom API URL
- [ ] Uses URL for subsequent requests

---

### 2.4 Whoami

```bash
blocksecops auth whoami
```

**Expected Output:**
```
┌──────────────────────────────────────────┐
│ Current User                              │
│                                           │
│ Email: user@example.com                   │
│ User ID: 529f5865-...                     │
│ Plan: developer                           │
│ API URL: https://api.blocksecops.com     │
└──────────────────────────────────────────┘
```

- [ ] Shows email
- [ ] Shows user ID
- [ ] Shows current plan
- [ ] Shows API URL

---

### 2.5 Status

```bash
blocksecops auth status
```

- [ ] Shows API URL
- [ ] Shows authentication status
- [ ] Indicates if connected

---

### 2.6 Logout

```bash
blocksecops auth logout
```

- [ ] Removes stored credentials
- [ ] Shows success message
- [ ] Subsequent commands require re-auth

---

## 3. Scan Commands

### 3.1 Scan File

```bash
blocksecops scan run contract.sol
```

- [ ] Uploads file to API
- [ ] Shows progress spinner
- [ ] Waits for completion
- [ ] Displays results table

---

### 3.2 Scan with No Wait

```bash
blocksecops scan run contract.sol --no-wait
```

- [ ] Returns immediately
- [ ] Shows scan ID
- [ ] Provides status command hint

---

### 3.3 Scan with Specific Scanners

```bash
blocksecops scan run contract.sol --scanner slither --scanner aderyn
```

- [ ] Uses only specified scanners
- [ ] Results from specified scanners only

---

### 3.4 Scan Status

```bash
blocksecops scan status <scan-id>
```

- [ ] Shows scan ID
- [ ] Shows current status
- [ ] Shows timestamps
- [ ] Shows error if failed

---

### 3.5 Scan Results

```bash
blocksecops scan results <scan-id>
```

- [ ] Shows full results
- [ ] Default table format
- [ ] Sorted by severity

---

### 3.6 Scan List

```bash
blocksecops scan list
```

- [ ] Lists recent contracts
- [ ] Shows ID, name, network, date
- [ ] Respects --limit flag

---

## 4. Output Formats

### 4.1 Table Format (Default)

```bash
blocksecops scan run contract.sol --output table
```

- [ ] Rich terminal formatting
- [ ] Color-coded severities
- [ ] Summary panel
- [ ] Vulnerabilities table

---

### 4.2 JSON Format

```bash
blocksecops scan run contract.sol --output json
```

- [ ] Valid JSON output
- [ ] scan object with ID, status
- [ ] summary with counts
- [ ] vulnerabilities array

---

### 4.3 SARIF Format

```bash
blocksecops scan run contract.sol --output sarif
```

- [ ] Valid SARIF 2.1.0 schema
- [ ] tool.driver with rules
- [ ] results array
- [ ] locations with file/line

---

### 4.4 JUnit Format

```bash
blocksecops scan run contract.sol --output junit
```

- [ ] Valid JUnit XML
- [ ] testsuites element
- [ ] testsuite per scanner
- [ ] testcase per vulnerability
- [ ] failure for critical/high

---

### 4.5 Output to File

```bash
blocksecops scan run contract.sol --output sarif --output-file results.sarif
```

- [ ] Writes to specified file
- [ ] Shows success message
- [ ] File contains valid format

---

## 5. Exit Codes

### 5.1 Fail on Severity

```bash
blocksecops scan run contract.sol --fail-on high
echo $?
```

- [ ] Exit 0 if no high/critical vulns
- [ ] Exit 1 if high/critical found
- [ ] Shows message about threshold

---

### 5.2 Fail on Critical

```bash
blocksecops scan run contract.sol --fail-on critical
```

- [ ] Only fails on critical
- [ ] High/medium/low don't fail

---

## 6. Configuration

### 6.1 Config File Location

- Linux/macOS: `~/.blocksecops/config.json`
- Windows: `%APPDATA%\blocksecops\config.json`

- [ ] Config file created on first use
- [ ] Contains api_url, default_output

---

### 6.2 Environment Variables

```bash
BLOCKSECOPS_API_KEY=xxx blocksecops auth status
```

- [ ] BLOCKSECOPS_API_KEY overrides stored key
- [ ] BLOCKSECOPS_API_URL overrides stored URL
- [ ] CI=true enables CI mode

---

### 6.3 CI Mode

```bash
CI=true blocksecops scan run contract.sol
```

- [ ] Disables interactive prompts
- [ ] Simplified output for logs

---

## 7. Pre-commit Integration

### 7.1 Install Pre-commit Framework Hook

Create `.pre-commit-config.yaml`:
```yaml
repos:
  - repo: https://github.com/blocksecops/blocksecops-cli
    rev: v0.1.0
    hooks:
      - id: blocksecops-scan
```

```bash
pre-commit install
```

- [ ] Hook installs successfully
- [ ] Runs on git commit

---

### 7.2 Standalone Hook

```bash
cp hooks/pre-commit-hook.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

- [ ] Hook is executable
- [ ] Scans staged .sol files
- [ ] Blocks commit on high/critical

---

### 7.3 Hook Skip

```bash
git commit --no-verify -m "skip hook"
```

- [ ] --no-verify skips hook
- [ ] SKIP_SECURITY_SCAN=1 skips

---

## 8. Error Handling

### 8.1 Not Authenticated

```bash
blocksecops scan run contract.sol
# (without login)
```

- [ ] Shows "Not authenticated" error
- [ ] Suggests running auth login

---

### 8.2 Invalid API Key

```bash
blocksecops auth login --api-key invalid_key
```

- [ ] Shows "Invalid API key" error
- [ ] Does not store invalid key

---

### 8.3 File Not Found

```bash
blocksecops scan run nonexistent.sol
```

- [ ] Shows "File not found" error
- [ ] Non-zero exit code

---

### 8.4 Network Error

- [ ] Shows connection error message
- [ ] Suggests checking network/URL

---

## 9. Help Commands

### 9.1 Global Help

```bash
blocksecops --help
```

- [ ] Shows all commands
- [ ] Shows global options

---

### 9.2 Command Help

```bash
blocksecops scan run --help
```

- [ ] Shows command options
- [ ] Shows argument descriptions

---

### 9.3 Version

```bash
blocksecops version
```

- [ ] Shows version number

---

## Test Status

| Section | Status | Date | Tester |
|---------|--------|------|--------|
| 1.1 pip Install | [ ] | | |
| 1.2 pipx Install | [ ] | | |
| 1.3 Source Install | [x] | 2026-01-04 | Claude Code |
| 2.1 Login | [ ] | | |
| 2.2 Login with Key | [ ] | | |
| 2.3 Login Custom URL | [ ] | | |
| 2.4 Whoami | [ ] | | |
| 2.5 Status | [ ] | | |
| 2.6 Logout | [ ] | | |
| 3.1 Scan File | [ ] | | |
| 3.2 Scan No Wait | [ ] | | |
| 3.3 Specific Scanners | [ ] | | |
| 3.4 Scan Status | [ ] | | |
| 3.5 Scan Results | [ ] | | |
| 3.6 Scan List | [ ] | | |
| 4.1 Table Format | [ ] | | |
| 4.2 JSON Format | [ ] | | |
| 4.3 SARIF Format | [ ] | | |
| 4.4 JUnit Format | [ ] | | |
| 4.5 Output File | [ ] | | |
| 5.1 Fail on High | [ ] | | |
| 5.2 Fail on Critical | [ ] | | |
| 6.1 Config File | [ ] | | |
| 6.2 Env Variables | [ ] | | |
| 6.3 CI Mode | [ ] | | |
| 7.1 Pre-commit Hook | [ ] | | |
| 7.2 Standalone Hook | [ ] | | |
| 7.3 Hook Skip | [ ] | | |
| 8.1 Not Authenticated | [ ] | | |
| 8.2 Invalid Key | [ ] | | |
| 8.3 File Not Found | [ ] | | |
| 8.4 Network Error | [ ] | | |
| 9.1 Global Help | [x] | 2026-01-04 | Claude Code |
| 9.2 Command Help | [x] | 2026-01-04 | Claude Code |
| 9.3 Version | [x] | 2026-01-04 | Claude Code |

---

## Notes

```
[Date] | [Tester] | [Note]
2026-01-04 | Claude Code | CLI tool implemented, pip install -e verified, help commands work
```
