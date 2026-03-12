# Smart Contract Pipeline Testing Playbook

**Version:** 1.0.0
**Last Updated:** February 9, 2026

## Overview

End-to-end testing playbook for the smart contract upload, scan, and result pipeline. Covers every supported file type, scanner, and lifecycle operation.

## Prerequisites

- API service running at `https://app.0xapogee.com`
- Valid JWT token (HS256 local dev: requires `sub` + `email` claims)
- User added to an organization
- Test fixtures at `/tmp/audit-fixtures/`

### Generate JWT

```bash
python3 -c "
from jose import jwt
import time
token = jwt.encode({
    'sub': '<user-supabase-id>',
    'email': 'user@blocksecops.dev',
    'type': 'access',
    'iat': int(time.time()),
    'exp': int(time.time()) + 86400
}, 'local-dev-jwt-secret-key-change-in-production', algorithm='HS256')
print(token)
"
```

### Test Fixture Creation

**Single files:**

| File | Content |
|------|---------|
| `test.sol` | Minimal Solidity contract with pragma, state, and function |
| `test.vy` | Minimal Vyper contract with `@version`, storage, and function |
| `test.rs` | Anchor/Solana program with `use anchor_lang::prelude::*` |

**Archives (create with Python zipfile):**

| Archive | Framework | Contents |
|---------|-----------|----------|
| `foundry-project.zip` | Foundry | `foundry.toml` + `src/Counter.sol` |
| `hardhat-project.zip` | Hardhat | `hardhat.config.js` + `contracts/Token.sol` |
| `plain-project.tar.gz` | Plain | Multiple `.sol` files, no config |
| `proxy-project.zip` | Plain | `Proxy.sol` + `Implementation.sol` |
| `upgradeable-project.zip` | Foundry | `foundry.toml` + `src/UpgradeableToken.sol` |

```bash
# Create zip archives (zip not installed on server)
python3 -c "
import zipfile, os
for proj in ['foundry-project', 'hardhat-project', 'proxy-project', 'upgradeable-project']:
    with zipfile.ZipFile(f'{proj}.zip', 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(proj):
            for f in files:
                fp = os.path.join(root, f)
                zf.write(fp, os.path.relpath(fp, '.'))
"

# Create tar.gz
tar czf plain-project.tar.gz plain-project/
```

## Phase 1: Upload Tests

**Important:** Use `contract_name` as a **query parameter** (not form field).

### Single File Uploads

```bash
# Solidity
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-sol" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@test.sol"
# Expected: 201, language=solidity

# Vyper
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-vy" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@test.vy"
# Expected: 201, language=vyper

# Rust/Solana
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-rs" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@test.rs"
# Expected: 201, language=rust
```

### Archive Uploads

```bash
# Foundry project
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-foundry" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@foundry-project.zip"
# Expected: 201, framework=foundry, is_multi_file=true

# Hardhat project
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-hardhat" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@hardhat-project.zip"
# Expected: 201, framework=hardhat, is_multi_file=true

# Plain .tar.gz
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-plain" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@plain-project.tar.gz"
# Expected: 201, framework=plain, is_multi_file=true
```

### Negative Tests

```bash
# Invalid extension -> 400
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=bad" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@test.txt"

# Duplicate name -> 409
curl -sk -w "\n%{http_code}" -X POST "$URL/upload?contract_name=test-sol" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -F "file=@test.sol"

# No auth -> 401
curl -sk -w "\n%{http_code}" -X POST "$URL/upload" -F "file=@test.sol"
```

### Verify Organization Context

```sql
SELECT name, language, organization_id FROM contracts
WHERE name LIKE 'test-%' ORDER BY created_at DESC;
-- All should have organization_id set
```

## Phase 2: Scan Tests

### Scanner Coverage Matrix

| Language | Scanners | Count |
|----------|----------|-------|
| Solidity | slither, aderyn, semgrep, solhint, wake, soliditydefend, echidna, medusa, halmos | 9 |
| Vyper | vyper, moccasin | 2 |
| Rust/Solana | sol-azy, sec3-xray, trident, cargo-fuzz-solana | 4 |
| **Total** | | **15** |

### Create Scans (Single Endpoint)

```bash
# Single scanner
curl -sk -w "\n%{http_code}" -X POST "$URL/scans" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -H "Content-Type: application/json" \
  -d '{"contract_id":"<id>","scanner_ids":["slither"]}'
# Expected: 201

# Note: Rate limited to ~5/minute. Use batch endpoint for bulk.
```

### Create Scans (Batch Endpoint)

```bash
# Multiple scanners at once
curl -sk -w "\n%{http_code}" -X POST "$URL/scans/batch" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG" \
  -H "Content-Type: application/json" \
  -d '{"contract_ids":["<id>"],"scanner_ids":["soliditydefend","echidna","medusa","halmos"]}'
# Expected: 201
```

### Verify Scan Completion

```sql
SELECT c.name, array_to_string(s.scanners_used, ',') as scanners,
       s.status, s.organization_id IS NOT NULL as has_org,
       s.critical_count + s.high_count + s.medium_count + s.low_count as vulns
FROM scans s JOIN contracts c ON s.contract_id = c.id
WHERE c.name LIKE 'test-%' ORDER BY c.name, s.created_at;
-- All should be status=completed, has_org=true
```

### Scanner Health

```bash
curl -s http://localhost:30810/scanners/health | python3 -m json.tool
```

## Phase 3: Result Verification

### Check Vulnerabilities

```bash
curl -sk "$URL/scans/<scan_id>/vulnerabilities" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG"
# Verify: fingerprint_code not null, category populated, scanner_id correct
```

### Check Severity Counts

```bash
curl -sk "$URL/scans/<scan_id>" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG"
# Verify: critical_count + high_count + medium_count + low_count match actual vulns
```

### Check Contract Status Transitions

- After upload: `status = "uploaded"`
- After scan creation: `status = "scanning"`
- After scan completion: `status = "scanned"`

## Phase 4: Delete Tests

```bash
# Delete scan
curl -sk -w "\n%{http_code}" -X DELETE "$URL/scans/<scan_id>" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG"
# Expected: 200, cascade deletes vulnerabilities

# Delete contract with scans
curl -sk -w "\n%{http_code}" -X DELETE "$URL/contracts/<contract_id>" \
  -H "Authorization: Bearer $JWT" -H "X-Organization-Id: $ORG"
# Expected: 200, cascade deletes scans
```

## Known Issues and Fixes

### Bugs Fixed in 0.28.6

| Bug | Fix |
|-----|-----|
| `archive_result.language` AttributeError (CRIT) | Changed to `detection_result.language.value` |
| Upload missing `organization_id` (CRIT) | Added `org_id` dependency + set on ContractModel |
| CORS missing `X-Organization-Id` (HIGH) | Added to `allow_headers` in main.py |
| Cairo/Move in Tier 1 despite no scanners | Demoted to Tier 2 |

### Bugs Fixed in 0.28.7

| Bug | Fix |
|-----|-----|
| Archive uploads fail with `.tmp` extension (CRIT) | Preserve original extension in safe_filename |
| `except Exception` catches HTTPException (HIGH) | Added `except HTTPException: raise` before generic handler |
| Batch scan missing `organization_id` (HIGH) | Added `org_id` to batch endpoint, set on ScanModel |
| Batch scan contract query not org-scoped (MED) | Added org-aware contract query |

### Known Limitations

- `contract_name` and `network` are query params (not form fields) due to FastAPI multipart handling
- No Cairo or Move scanners exist (languages are Tier 2)
- Rate limit on scan creation (~5/minute for single endpoint; use batch for bulk)
- Empty files (0 bytes) are accepted without validation
