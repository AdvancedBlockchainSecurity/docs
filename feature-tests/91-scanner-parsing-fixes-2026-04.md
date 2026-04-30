# Scanner Parsing Fixes — April 2026

**Date:** 2026-04-12
**Version:** tool-integration 0.5.42
**Scanners Fixed:** Mythril, Echidna, Halmos, Medusa, Vyper

---

## Overview

Comprehensive audit and fix of all 17 scanner images. Found that 5 scanners (Mythril, Echidna, Halmos, Medusa, Vyper) had parsing or runtime bugs preventing them from producing findings. All were fixed and locally tested with vulnerable contracts that produce verifiable findings.

---

## Scanner Fixes

### Mythril (0.1.7)

**Root causes:**
1. `py-solc-x` not pre-installed — mythril uses `solcx` (not `solc-select`), causing `PermissionError` on `/tmp/.solcx-lock-*` files left by root during build
2. 4byte.directory signature DB not pre-populated — mythril tried to download at runtime, blocked by NetworkPolicy, causing indefinite hang
3. `HTTPS_PROXY` workaround crashed entire analysis with `{"success": false}`

**Fixes applied:**
- Pre-install solc via `py-solc-x` at build time, seed to `/opt/solcx/`
- Pre-populate mythril signature DB via build-time analysis, seed to `/opt/mythril/`
- Runtime seeding from `/opt/` to `$HOME/` (survives K8s emptyDir mount)
- Removed proxy env vars; added `{"success": false}` response detection

**Test result:** Found SWC-105 (Unprotected Ether Withdrawal) on test contract

### Echidna (0.3.10)

**Root causes:**
1. `echo "$SOLC_VERSION"` wrote trailing newline to `~/.solc-select/global-version` — solc-select treated `"0.8.20\n"` as unknown version
2. Echidna v2.2.7 outputs text lines then JSON on final line — `jq empty` failed on mixed output
3. Parser checked `"status": "solved"` but echidna outputs `"status": "shrinking"` when test limit is reached before shrinking completes
4. Original parser used Python `json.load()` expecting `data["tests"]` with `test.get("passed", True)` — echidna v2.2.7 uses `"status"` field, not `"passed"` boolean

**Fixes applied:**
- Changed `echo` to `printf '%s'` for global-version file
- Added `grep '^{'` to extract JSON from mixed text+JSON output
- Added `"shrinking"` to status filter alongside `"solved"`
- Rewrote parser from Python to jq for reliability

**Test result:** Found property violation (`echidna_flag_is_false` falsified via `setCounter()`)

### Halmos (0.3.10)

**Root causes:**
1. Default solver `yices-smt2` crashes with SIGILL on some CPU architectures
2. `--depth 64` too restrictive — caused REVERT_ALL on trivially solvable contracts
3. JSON parser used non-existent `.results[]` path — halmos uses `.test_results{}` (dict keyed by contract path)
4. Parser referenced non-existent fields (`test_name`, `contract_name`, `counterexample`, `timeout` boolean)

**Fixes applied:**
- Changed solver to `z3` via `--solver-command z3`
- Increased default depth from 64 to 256
- Rewrote JSON parsing to use `.test_results | to_entries[]` with correct field names (`name`, `exitcode`, `models`)
- Added forge-std seeding from `/opt/forge-std/` for contracts that import it

**Test result:** Found 2 counterexamples — `check_x_not_42(val=42)` and `check_add_safe(a=1, b=MAX_UINT256)`

### Medusa (0.3.8)

**Root causes:**
1. Alpine base image lacks glibc — solc binaries (glibc-linked) fail with `FileNotFoundError` ("cannot execute: required file not found")
2. `crytic-compile` called `solc-select install` which tried to download version list from internet (403)
3. Grep patterns wrong: `[FAILED]` appears BEFORE test type name, not after (e.g., `[FAILED] Property Test:` not `Property Test.*FAILED`)
4. No `"Panic code:"` string in medusa output — uses `[panic: reason]` format
5. Stats extraction used `"Tests ran:"` and `"Call sequences:"` — medusa uses `"Test summary: N test(s) passed, N test(s) failed"`

**Fixes applied:**
- Added `gcompat` package to Alpine for glibc compatibility
- Removed hardcoded `solcVersion` from crytic-compile config (uses pre-installed solc)
- Fixed all grep patterns to match actual medusa v1.5.0 output format
- Fixed panic detection: `\[panic:` instead of `Panic code:`
- Fixed stats: parse `Test summary:` line

**Test result:** Found property violation (`property_never_breached()` failed via `setValue(123456)`)

### Vyper (0.3.5)

**Root causes:**
1. `crytic-compile` assumes `sourceMap` is a string, but Vyper 0.4.x returns it as a dict — `AttributeError: 'dict' object has no attribute 'split'`
2. Slither AST parser accesses `raw["keyword"]` but Vyper 0.4.x removed this field — `KeyError: 'keyword'`
3. Slither expects `module.name` to be a string, but Vyper 0.4.x sets it to `None` — `TypeError`

**Fixes applied:**
- Build-time Python patch script (`patch-crytic-compile.py`) that fixes all three issues
- Upgraded slither from 0.11.3 to 0.11.5
- Vyper 0.3.x: fully working (found reentrancy + 2 more issues)
- Vyper 0.4.x: patches prevent crashes but deeper slither AST incompatibilities remain (upstream limitation, slither warns "Vyper != 0.3.7 support is a best effort")

**Test result:** Vyper 0.3.x — found 3 issues (reentrancy, unchecked send, informational). Vyper 0.4.x — graceful empty result (no crash)

---

## Additional Fixes (from prior session, included in this release)

- **Solhint (0.1.13):** Added `--disc` flag to prevent update check hang; fixed JSON extraction with `grep '^\['`
- **tool-integration main.py:** Added `scanner_results` unwrapping before parser routing (scanners like aderyn, solhint wrap payload in `{"scanner_results": {...}}`)
- **All scanner entrypoints:** Added `X-Internal-Service-Token` header for callback authentication

---

## Version Changes

| Component | Old | New |
|-----------|-----|-----|
| tool-integration | 0.5.41 | 0.5.42 |
| scanner-mythril | 0.1.6 | 0.1.7 |
| scanner-echidna | 0.3.9 | 0.3.10 |
| scanner-halmos | 0.3.9 | 0.3.10 |
| scanner-medusa | 0.3.7 | 0.3.8 |
| scanner-vyper | 0.3.4 | 0.3.5 |
| scanner-solhint | 0.1.12 | 0.1.13 |

---

## Verification

All scanners tested locally with `docker run` against purpose-built vulnerable contracts:

| Scanner | Contract | Expected Finding | Result |
|---------|----------|-----------------|--------|
| Mythril | MythrilSimple.sol | SWC-105 unprotected withdrawal | 1 HIGH |
| Echidna | EchidnaTest.sol | `echidna_flag_is_false` violated | 1 property violation |
| Halmos | HalmosTest.sol | val=42, overflow counterexamples | 2 CRITICAL |
| Medusa | MedusaTest.sol | `property_never_breached` violated | 1 HIGH |
| Vyper | vulnerable_v3.vy | Reentrancy in withdraw() | 3 findings |
| Slither | Vulnerable.sol | Reentrancy, tx.origin, etc. | Multiple |
| Aderyn | Vulnerable.sol | Reentrancy, unchecked returns | 4+ |
| Semgrep | Vulnerable.sol | Pattern match | 1 |
| Solhint | Vulnerable.sol | Style/best practice | 35 |
| Wake | Vulnerable.sol | Potential issues | 5 |
| SolidityDefend | Vulnerable.sol | 1 crit, 1 high, 1 medium | 3 |
| RustDefend | Solana program | Missing signer check | 2 |
| Sol-Azy | Solana program | Completed | 0 |
| Sec3-Xray | Solana program | Completed | 0 |
| Cargo-Fuzz | Solana program | Fuzzed, no crashes | 0 |
| Moccasin | Vyper contract | Completed | 0 |
| Trident | Requires Anchor | Correct error | N/A |

---

## Known Limitations

1. **Vyper 0.4.x:** Slither's Vyper parser has fundamental AST incompatibilities with 0.4.x. Scanner gracefully returns empty results. Requires upstream slither update.
2. **Trident:** Requires full Anchor framework project. Platform's ConfigMap-based contract delivery cannot provide full Anchor project structure with crate dependencies.

---

## Mythril Offline OZ Resolution via --solc-json (Task #176, 2026-04-29)

**Scanner version:** scanner-mythril:0.2.7
**Related task:** Task #176

### Feature

Mythril can now analyze Hardhat projects that import `@openzeppelin/contracts/...` without reaching the network. The fix addresses the root cause: mythril uses solc Standard JSON mode (`--standard-json`) which rejects positional remapping arguments (`--remappings prefix=path`) but correctly honors `settings.remappings` inside a JSON settings file. The wrapper now conditionally writes `/tmp/solc-settings.json` with the OZ remapping and passes `--solc-json /tmp/solc-settings.json` to `myth analyze` when `@openzeppelin/contracts/` imports are detected.

### Verification

| Test type | Contract | Scan ID | Result |
|-----------|----------|---------|--------|
| Cluster (production) | Hardhat+OZ ERC20 single-file (`0c7542c6-1c12-4a15-8421-ff959f21c214`) | `c8a40192-4965-4817-999e-78a6e7a1d9f7` | `completed`, ~2m12s, no urllib3 error |
| Local docker (`--network=none`) | Constructed Hardhat+OZ fixture | n/a | Compiled cleanly, analysis ran to completion |

### Scope

Works for: single-file Hardhat contracts importing `@openzeppelin/contracts/` v5.0.2 (bundled in `scanner-base-solidity:1.1.0-b49e3f10`).

Not yet working: multi-file Hardhat projects (Task #182, filed 2026-04-29).

### Regression tests

7 tests in `tests/regression/test_mythril_solc_json_remappings.py` covering flag wiring, MYTH_EXTRA_ARGS expansion, OZ-import-conditional guard, no-OZ baseline, `--solc-args` dead-end regression check, Dockerfile chown fix, and image version pins.
