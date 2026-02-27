# Contract Upload Pipeline

Handles smart contract upload, validation, storage, and optional scan triggering.

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
| 3 | Language detection | Auto-detect from source code content or file extension. Supported: `solidity`, `vyper`, `rust`, `move`, `cairo` |
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

| Language | Enum Value | Detection |
|----------|------------|-----------|
| Solidity | `solidity` | `.sol` extension, `pragma solidity` |
| Vyper | `vyper` | `.vy` extension |
| Rust (Solana) | `rust` | `.rs` extension, `use anchor_lang` |
| Move | `move` | `.move` extension |
| Cairo | `cairo` | `.cairo` extension |

## Error Handling

| Error | Status | Description |
|-------|--------|-------------|
| Duplicate name | 409 | Contract with same name already exists for user |
| Invalid language | 400 | Language not in supported enum |
| Auth failure | 401/403 | Invalid token/key or insufficient scope |
| Invalid address | 400 | Address fails `^0x[0-9a-fA-F]{40}$` validation (silently ignored) |
| Validation error | 422 | Missing required fields in request body |
