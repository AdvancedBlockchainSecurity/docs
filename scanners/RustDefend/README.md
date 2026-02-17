# RustDefend Scanner

## Overview

RustDefend is a BlockSecOps proprietary Rust smart contract static analysis scanner. It performs AST-based analysis using the Rust `syn` crate to detect security vulnerabilities in smart contracts across multiple blockchain ecosystems.

---

## Scanner Details

| Property | Value |
|----------|-------|
| **Tool Version** | 0.4.0 |
| **Docker Image** | `scanner-rustdefend:0.4.0` |
| **Language** | Rust |
| **Analysis Method** | AST-based static analysis via `syn` crate |
| **Output Format** | JSON array of findings |
| **Total Detectors** | 50 |

---

## Supported Ecosystems

| Ecosystem | Detector Count |
|-----------|---------------|
| Solana | 14 |
| CosmWasm | 11 |
| NEAR | 12 |
| Ink! | 11 |
| Cross-chain / Dependency | 2 |
| **Total** | **50** |

---

## CLI Usage

```
rustdefend scan <path> --format json [--chain solana] [--severity critical,high]
```

### Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `<path>` | Yes | Path to the Rust project or file to scan |

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--format` | `text` | Output format: `json`, `text`, `sarif` |
| `--chain` | all | Filter detectors by chain: `solana`, `cosmwasm`, `near`, `ink` |
| `--severity` | all | Filter findings by severity: `critical`, `high`, `medium`, `low`, `info` |
| `--output` | stdout | Write output to a file path |
| `--verbose` | false | Enable verbose logging |

### Examples

Scan a Solana project for critical and high severity findings:
```bash
rustdefend scan ./my-solana-program --format json --chain solana --severity critical,high
```

Scan all Rust contracts and output to a file:
```bash
rustdefend scan ./contracts --format json --output results.json
```

Full scan with verbose logging:
```bash
rustdefend scan . --format json --verbose
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Clean -- no findings detected |
| `1` | Findings detected -- results written to output |
| `2` | Invalid input -- path does not exist or is not a valid Rust project |

---

## Output Format

RustDefend outputs a JSON array of finding objects:

```json
[
  {
    "detector": "solana-missing-signer-check",
    "severity": "critical",
    "confidence": "high",
    "title": "Missing Signer Check",
    "description": "Account is used without verifying the signer flag.",
    "file": "src/processor.rs",
    "line": 42,
    "column": 8,
    "snippet": "let user_account = next_account_info(account_iter)?;",
    "recommendation": "Add a signer check: require!(user_account.is_signer, ProgramError::MissingRequiredSignature)",
    "ecosystem": "solana",
    "cwe": "CWE-285"
  }
]
```

### Finding Fields

| Field | Type | Description |
|-------|------|-------------|
| `detector` | string | Unique detector identifier |
| `severity` | string | `critical`, `high`, `medium`, `low`, `info` |
| `confidence` | string | `high`, `medium`, `low` |
| `title` | string | Human-readable finding title |
| `description` | string | Detailed description of the issue |
| `file` | string | Relative file path where the issue was found |
| `line` | integer | Line number of the finding |
| `column` | integer | Column number of the finding |
| `snippet` | string | Source code snippet at the finding location |
| `recommendation` | string | Suggested remediation |
| `ecosystem` | string | Target blockchain ecosystem |
| `cwe` | string | Associated CWE identifier |

---

## Docker Image

### Image Details

| Property | Value |
|----------|-------|
| **Image Name** | `scanner-rustdefend` |
| **Tag** | `0.4.0` |
| **Base Image** | `rust:1.85-slim-bookworm` (builder), `debian:bookworm-slim` (runtime) |
| **Entrypoint** | `/usr/local/bin/rustdefend-scan` |

### Running via Docker

```bash
docker run --rm -v $(pwd)/contracts:/workspace scanner-rustdefend:0.4.0 scan /workspace --format json
```

---

## Platform Integration Points

### Kubernetes (ConfigMap + KJM)
- Registered in base, local, and production ConfigMap overlays.
- KJM configuration defines: image, command, memory_limit (1Gi), memory_request (512Mi), timeout (300s).

### Output Parser
- Custom parser (`rustdefend_parser.py`) transforms JSON findings into BlockSecOps normalized format.
- Registered in the parser registry.

### API
- Metadata registered in SCANNERS dictionary (name, key, version, ecosystems, detector count).
- Included in PRESETS: `rust`, `smart-contract`, `full`.

### Orchestration
- Dedicated executor (`rustdefend_executor.py`) manages the full scan lifecycle.
- Registered in the scanner executor registry.

### Admin Portal
- Listed in SCANNERS array with display metadata (name, description, icon, supported chains).
- NAME_TO_KEY mapping for internal routing.

### Vulnerability Patterns
- 36 BVD patterns mapped to RustDefend detectors.
- Database seed script for initial deployment.

---

## Detector Categories

### Solana (14 Detectors)

| Detector ID | Severity | Description |
|-------------|----------|-------------|
| `solana-missing-signer-check` | Critical | Missing signer verification on accounts |
| `solana-missing-owner-check` | Critical | Missing owner validation on accounts |
| `solana-arbitrary-cpi` | Critical | Unrestricted cross-program invocation |
| `solana-pda-seed-collision` | Critical | PDA seed derivation collision risk |
| `solana-integer-overflow` | High | Arithmetic without overflow checks |
| `solana-uninitialized-account` | High | Use of uninitialized account data |
| `solana-duplicate-mutable-accounts` | High | Same account passed as multiple mutable references |
| `solana-closing-account-missing-zero` | High | Account not zeroed before closing |
| `solana-type-cosplay` | High | Account type confusion vulnerability |
| `solana-insecure-init` | Medium | Account initialization without proper checks |
| `solana-bump-seed-not-validated` | Medium | PDA bump seed not validated |
| `solana-missing-rent-exempt` | Medium | Missing rent exemption check |
| `solana-deprecated-api` | Medium | Use of deprecated Solana API calls |
| `solana-hardcoded-pubkey` | Medium | Hardcoded public keys in source |

### CosmWasm (11 Detectors)

| Detector ID | Severity | Description |
|-------------|----------|-------------|
| `cosmwasm-reentrancy` | Critical | Reentrancy via submessage callbacks |
| `cosmwasm-unauthorized-execute` | Critical | Missing authorization on execute entry point |
| `cosmwasm-unchecked-cosmwasm-addr` | High | Unvalidated address input |
| `cosmwasm-integer-overflow` | High | Arithmetic without overflow protection |
| `cosmwasm-storage-collision` | High | Conflicting storage key prefixes |
| `cosmwasm-unbounded-query` | Medium | Query without pagination limits |
| `cosmwasm-missing-migration` | Medium | Contract upgrade without migration handler |
| `cosmwasm-unused-reply` | Medium | Unhandled reply entry point |
| `cosmwasm-hardcoded-denom` | Medium | Hardcoded token denomination |
| `cosmwasm-unchecked-reply-id` | High | Reply ID not validated in reply entry point |
| `cosmwasm-admin-takeover` | Critical | Admin can be changed without proper authorization |

### NEAR (12 Detectors)

| Detector ID | Severity | Description |
|-------------|----------|-------------|
| `near-predecessor-check-missing` | Critical | Missing predecessor account validation |
| `near-reentrancy-promise` | Critical | Reentrancy via promise callbacks |
| `near-storage-unguarded` | Critical | Unprotected storage writes |
| `near-integer-overflow` | High | Arithmetic without overflow protection |
| `near-unregistered-transfer` | High | NEP-141 transfer without storage registration |
| `near-unchecked-promise-result` | High | Unhandled promise result |
| `near-self-callback-missing` | Medium | Missing self-callback validation |
| `near-unnecessary-public` | Medium | Unnecessarily public contract method |
| `near-storage-bloat` | Medium | Unbounded collection growth risk |
| `near-deprecated-api` | Medium | Use of deprecated NEAR SDK calls |
| `near-missing-assert-one-yocto` | High | Missing 1 yoctoNEAR deposit assertion for sensitive operations |
| `near-public-key-validation` | Medium | Missing public key format validation |

### Ink! (11 Detectors)

| Detector ID | Severity | Description |
|-------------|----------|-------------|
| `ink-reentrancy` | Critical | Reentrancy via cross-contract calls |
| `ink-missing-caller-check` | Critical | Missing caller authorization |
| `ink-integer-overflow` | High | Arithmetic without overflow protection |
| `ink-uninitialized-storage` | High | Access to uninitialized contract storage |
| `ink-unbounded-vec` | High | Unbounded vector in contract storage |
| `ink-panic-in-contract` | Medium | Use of panic! or unwrap in contract code |
| `ink-missing-error-handling` | Medium | Insufficient error handling in dispatches |
| `ink-unused-return` | Medium | Unhandled return values from cross-contract calls |
| `ink-deprecated-api` | Medium | Use of deprecated Ink! API calls |
| `ink-hardcoded-hash` | Medium | Hardcoded code hash for delegate calls |
| `ink-missing-transfer-check` | High | Missing balance check before transfer |

### Cross-chain / Dependency (2 Detectors)

| Detector ID | Severity | Description |
|-------------|----------|-------------|
| `dep-vulnerable-crate` | Critical | Known vulnerable crate dependency |
| `cross-chain-bridge-validation` | High | Insufficient cross-chain message validation |
