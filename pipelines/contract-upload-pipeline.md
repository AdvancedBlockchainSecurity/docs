# Contract Upload Pipeline

Handles smart contract upload, validation, storage, and optional scan triggering.

**Sibling pipelines:**
- [GitHub URL Ingest Pipeline](./github-url-ingest-pipeline.md) — `POST /api/v1/contracts/from-github` (added api-service 0.37.x)
- [Contract Ingest Workflow](../workflows/contract-ingest-workflow.md) — comparison of all four ingest methods

## Overview

```
Dashboard / API Key         API Service (contracts.py)                 Database
───────────────────         ─────────────────────────                  ────────
POST /contracts     →       1. Authenticate (JWT or API key)           contracts
                            2. Check name uniqueness                   contract_files
                            3. Validate language                       project_contracts
                            4. Detect language from source/extension
                            5. Count lines of code
                            6. Store contract record
                            7. Store contract files (multi-file)
                     ←      Return ContractResponse (201)

Optional:
POST /scans         →       Trigger scan on uploaded contract          scans
```

## Trigger

- **Dashboard**: User uploads a contract via the upload form
- **API Key**: External tool calls `POST /api/v1/contracts` with `X-API-Key` header
- **CLI**: `0xapogee-cli` uploads via API key

## Pipeline Steps

| # | Step | Description |
|---|------|-------------|
| 1 | Authentication | Dual-auth: JWT (`Authorization: Bearer`) or API key (`X-API-Key`) with `contracts:write` scope |
| 2 | Name check | Verify no existing contract with same name for user (`409 Conflict` if duplicate) |
| 3 | Language detection | Auto-detect from source code content or file extension. Supported: `solidity`, `vyper`, `rust`, `move` |
| 4 | Validation | Validate `ContractCreate` schema: name, source_code/files, optional network/address |
| 5 | Line counting | Count lines of code from source for metrics |
| 6 | Store contract | Insert into `contracts` table with metadata (language, framework, compiler_version) |
| 7 | Store files | For multi-file projects: insert each file into `contract_files` with path and content |
| 8 | Response | Return `ContractResponse` with ID, vulnerability counts (initially zero), project/tag associations |

## Multi-File Project Support

Projects with `is_multi_file: true` include:
- Multiple source files with relative paths
- Framework detection (`foundry`, `hardhat`, `plain`)
- Framework configuration (remappings, compiler settings)
- Main file designation (`main_file_path`)

## Authentication

| Method | Header | Scope Required | Use Case |
|--------|--------|----------------|----------|
| JWT | `Authorization: Bearer <token>` | Implicit (user session) | Dashboard uploads |
| API Key | `X-API-Key: <key>` | `contracts:write` | CLI, CI/CD integrations |

Write endpoints use `require_auth_with_scope()` per [API Endpoint Authentication standards](../standards/api-endpoint-auth.md).
Read-only endpoints (list, detail) accept both via `get_current_user_or_api_key`.

## Data Flow

```
ContractCreate (name, source_code, language?, files?, address?)
      │
      ▼
Language Detection (auto-detect or explicit)
      │
      ▼
ContractModel (id, user_id, name, language, address?, status="uploaded")
      │
      ▼
ContractFileModel[] (for multi-file: path, content, is_main_file)
      │
      ▼
ContractResponse (id, vulnerabilities: {0,0,0,0}, projects, tags)
```

## Files

| File | Role |
|------|------|
| `blocksecops-api-service/src/presentation/api/v1/endpoints/contracts.py` | REST endpoints: create, list, detail, update, delete |
| `blocksecops-api-service/src/presentation/schemas/contracts.py` | Pydantic schemas: `ContractCreate`, `ContractResponse`, `ContractListResponse` |
| `blocksecops-api-service/src/infrastructure/database/models.py` | `ContractModel`, `ContractFileModel`, `ContractLanguage` enum |
| `blocksecops-api-service/src/infrastructure/auth/api_key_auth.py` | `require_auth_with_scope()` for write operations |

## Supported Languages

| Language | Enum Value | Detection | Single File | Project Archive |
|----------|------------|-----------|-------------|-----------------|
| Solidity | `solidity` | `.sol` extension, `pragma solidity` | yes | yes (Foundry, Hardhat) |
| Vyper | `vyper` | `.vy` extension | yes | yes |
| Rust (Solana) | `rust` | `.rs` extension, `use anchor_lang` | yes | yes (Anchor) — added 2026-04-13 in api-service 0.36.2 |
| Move | `move` | `.move` extension | yes | no |

### Framework Detection (`framework_detector.py`)

| Framework | Trigger File | Source Directory | Dependency Dir |
|-----------|-------------|------------------|----------------|
| `anchor` | `Anchor.toml` | `programs/` | none (crates pre-vendored in scanner images) |
| `foundry` | `foundry.toml` | `src/` | `lib/` |
| `hardhat` | `hardhat.config.{js,ts}` | `contracts/` | `node_modules/` |
| `plain` | none of the above | `src/`, `contracts/`, `programs/`, `source/` | none |

Anchor has highest detection priority (`Anchor.toml` is unambiguous). Then Foundry, Hardhat, Plain.

### Multi-Language Archive Extraction (`archive_extractor.py`)

The archive extractor walks all `*.sol`, `*.rs`, `*.vy` files and classifies each by language. Config files (`Anchor.toml`, `Cargo.toml`, `foundry.toml`, `hardhat.config.*`, `package.json`, `remappings.txt`) are extracted alongside contract files. Solidity-only dependency resolution (import remapping) is skipped for Rust/Vyper projects.

## Input Validation (v0.29.43)

### ContractCreate model_validator

A Pydantic `model_validator` enforces that every contract creation request includes at least one of `address` or `source_code`. Requests that provide neither are rejected before any database write.

| Condition | Status | Description |
|-----------|--------|-------------|
| Neither `address` nor `source_code` provided | 422 | At least one field is required |
| `source_code` provided | proceeds | Normal flow |
| `address` only | proceeds | Address-only contract (no source) |

### Source Code Size Limit

A global `RequestSizeLimitMiddleware` (10 MB) applies to `POST /api/v1/contracts` inline source submissions. Requests that exceed 10 MB are rejected before the endpoint handler runs.

| Condition | Status | Description |
|-----------|--------|-------------|
| `source_code` ≤ 10 MB | proceeds | Normal flow |
| `source_code` > 10 MB | 413 | Request Entity Too Large |

### Null Byte Rejection

Source code content is checked for null bytes (`\x00`) before storage. Null bytes indicate binary or corrupted content, not valid source text.

| Condition | Status | Description |
|-----------|--------|-------------|
| No null bytes in content | proceeds | Normal flow |
| Null byte detected | 400 | Null bytes are not permitted in source code |

### Binary Signature Detection (File Uploads)

The `POST /api/v1/upload` endpoint inspects the first bytes of every uploaded file against known binary magic numbers before processing. This prevents executable or document binaries from being stored as source code.

| Format | Magic Bytes | Detection |
|--------|-------------|-----------|
| ELF (Linux binary) | `\x7fELF` | Bytes 0–3 |
| PE (Windows binary) | `MZ` | Bytes 0–1 |
| Mach-O (macOS binary) | `\xcf\xfa\xed\xfe` / `\xce\xfa\xed\xfe` | Bytes 0–3 |
| WASM module | `\x00asm` | Bytes 0–3 |
| OLE2 compound doc | `\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1` | Bytes 0–7 |
| PDF | `%PDF` | Bytes 0–3 |

| Condition | Status | Description |
|-----------|--------|-------------|
| File passes signature check | proceeds | Normal flow |
| Binary signature detected | 400 | Binary files are not permitted |

## Error Handling

| Error | Status | Description |
|-------|--------|-------------|
| Duplicate name | 409 | Contract with same name already exists for user |
| Invalid language | 400 | Language not in supported enum |
| Auth failure | 401/403 | Invalid token/key or insufficient scope |
| Invalid address | 400 | Address fails `^0x[0-9a-fA-F]{40}$` validation (silently ignored) |
| Validation error | 422 | Missing required fields in request body |
| Neither address nor source_code | 422 | `model_validator` requires at least one |
| Source code > 10 MB | 413 | Request body too large |
| Null bytes in source | 400 | Binary/corrupt content rejected |
| Binary file upload | 400 | Magic number signature detected |
