# Scanner Endpoints

Base URL: `/api/v1/scanners`

These endpoints provide information about available security scanners, their capabilities, and predefined scan presets grouped by language.

## Endpoints

| Method | Path | Auth Required | Description |
|--------|------|---------------|-------------|
| GET | `/api/v1/scanners` | Yes | List all available scanners |
| GET | `/api/v1/scanners/{scanner_id}` | Yes | Get scanner detail |
| GET | `/api/v1/scanners/presets/{language}` | Yes | List scan presets for a language |
| GET | `/api/v1/scanners/presets/{language}/{preset_name}` | Yes | Get a specific preset |

---

## GET `/api/v1/scanners`

Returns the full list of available security scanners.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/scanners \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "scanners": [
    {
      "id": "slither",
      "name": "Slither",
      "description": "Static analysis framework for Solidity",
      "type": "static",
      "languages": ["solidity"],
      "version": "0.10.0",
      "is_production_ready": true
    }
  ],
  "total": 15
}
```

| Field | Type | Description |
|-------|------|-------------|
| `scanners` | array | List of scanner objects |
| `scanners[].id` | string | Unique scanner identifier |
| `scanners[].name` | string | Display name |
| `scanners[].description` | string | Short description of the scanner |
| `scanners[].type` | string | Scanner type (`static`, `dynamic`, `fuzzer`, `formal_verification`) |
| `scanners[].languages` | array | Supported languages |
| `scanners[].version` | string | Current scanner version |
| `scanners[].is_production_ready` | boolean | Whether the scanner is production-ready |
| `total` | integer | Total number of scanners |

### Available Scanners (15 total)

| # | Scanner ID | Name | Type | Languages |
|---|-----------|------|------|-----------|
| 1 | `slither` | Slither | static | Solidity |
| 2 | `aderyn` | Aderyn | static | Solidity |
| 3 | `semgrep` | Semgrep | static | Solidity, Rust |
| 4 | `solhint` | Solhint | static | Solidity |
| 5 | `wake` | Wake | static | Solidity |
| 6 | `soliditydefend` | SolidityDefend | static | Solidity |
| 7 | `halmos` | Halmos | formal_verification | Solidity |
| 8 | `echidna` | Echidna | fuzzer | Solidity |
| 9 | `medusa` | Medusa | fuzzer | Solidity |
| 10 | `mythril` | Mythril | static | Solidity |
| 11 | `trident` | Trident | fuzzer | Solana/Rust |
| 12 | `cargo-fuzz-solana` | Cargo Fuzz (Solana) | fuzzer | Solana/Rust |
| 13 | `clippy` | Clippy | static | Rust |
| 14 | `soteria` | Soteria | static | Solana/Rust |
| 15 | `anchor-verify` | Anchor Verify | static | Solana/Rust |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/scanners/{scanner_id}`

Returns detailed information about a specific scanner.

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `scanner_id` | string | Yes | Unique scanner identifier (e.g., `slither`) |

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/scanners/slither \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "id": "slither",
  "name": "Slither",
  "description": "Static analysis framework for Solidity",
  "type": "static",
  "languages": ["solidity"],
  "version": "0.10.0",
  "is_production_ready": true,
  "detectors": [],
  "configuration_options": {}
}
```

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/scanners/presets/{language}`

Returns all available scan presets for a given language.

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `language` | string | Yes | Programming language (e.g., `solidity`, `rust`) |

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/scanners/presets/solidity \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "language": "solidity",
  "presets": [
    {
      "name": "quick",
      "scanners": 4,
      "estimated_duration_seconds": 105,
      "description": "Fast scan with core static analyzers"
    },
    {
      "name": "standard",
      "scanners": 7,
      "estimated_duration_seconds": 235,
      "description": "Balanced scan with static analysis and linting"
    },
    {
      "name": "deep",
      "scanners": 9,
      "estimated_duration_seconds": 510,
      "description": "Comprehensive scan including fuzzers and formal verification"
    }
  ]
}
```

### Solidity Presets

| Preset | Scanners | Estimated Duration | Description |
|--------|----------|--------------------|-------------|
| `quick` | 4 | ~105 seconds | Fast scan with core static analyzers |
| `standard` | 7 | ~235 seconds | Balanced scan with static analysis and linting |
| `deep` | 9 | ~510 seconds | Comprehensive scan including fuzzers and formal verification |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/scanners/presets/{language}/{preset_name}`

Returns the details of a specific preset, including the list of scanners it includes.

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `language` | string | Yes | Programming language (e.g., `solidity`) |
| `preset_name` | string | Yes | Preset name (e.g., `quick`, `standard`, `deep`) |

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/scanners/presets/solidity/standard \
  -H "Authorization: Bearer <token>"
```

### Response `200 OK`

```json
{
  "name": "standard",
  "language": "solidity",
  "scanners": [
    "slither",
    "aderyn",
    "semgrep",
    "solhint",
    "wake",
    "soliditydefend",
    "mythril"
  ],
  "estimated_duration_seconds": 235,
  "description": "Balanced scan with static analysis and linting"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Preset name |
| `language` | string | Target language |
| `scanners` | array | List of scanner IDs included in this preset |
| `estimated_duration_seconds` | integer | Estimated total scan time |
| `description` | string | Human-readable description |

### Audit Status

- **Pass** — No issues identified.
