# Framework Support Matrix

This document provides a comprehensive overview of Apogee framework support, including which scanners work with each framework and known limitations.

## Framework Detection

Apogee automatically detects your project framework based on configuration files:

| Framework | Detection File | Priority |
|-----------|----------------|----------|
| Foundry | `foundry.toml` | 1 (highest) |
| Hardhat | `hardhat.config.js` or `hardhat.config.ts` | 2 |
| Plain | Neither present | 3 (default) |

**Note**: If both `foundry.toml` and `hardhat.config.js` exist, Foundry takes precedence.

## Scanner Compatibility Matrix

### By Framework

| Scanner | Single File | Foundry | Hardhat | Notes |
|---------|-------------|---------|---------|-------|
| **Slither** | Full | Full | Full | Hardhat projects converted to Foundry layout at scan time (offline-compatible). OZ 5.x bundled — see Hardhat Support Details. Foundry+OZ projects without a declared remapping resolved correctly (Task #179, scanner-slither:0.4.7). |
| **Aderyn** | Full | Full | Full | Hardhat → Foundry conversion (Task #172 sweep). OZ 5.x bundled. Foundry+OZ projects without a declared remapping resolved correctly (Task #179, scanner-aderyn:0.8.5). |
| **SolidityDefend** | Full | Full | Full | Apogee premier scanner. v2.0.10 (scanner-soliditydefend:0.10.0). Foundry+OZ remappings.txt sweep applied. |
| **Echidna** | Full | Full | Full | Hardhat → Foundry conversion. Foundry+OZ remappings.txt sweep applied (Task #179, scanner-echidna:0.5.4). Note: only finds issues on contracts with `echidna_*` invariant tests. |
| **Halmos** | Full | Full | Full | Symbolic execution. Hardhat → Foundry conversion. OZ 5.x bundled. |
| **Wake** | Full | Full | Full | Foundry+OZ projects: wake-scan writes `wake.toml` with `target_version` + OZ remapping when wake.toml is absent and OZ imports are detected (scanner-wake:0.5.8, Task #192). Without `target_version`, wake's compile pipeline triggers an outbound aiohttp call to `binaries.soliditylang.org` that the scanner NetworkPolicy egress block correctly denies. With `target_version` and the seeded `/opt/wake-compilers` cache, wake compiles fully offline. |
| **Mythril** | Full | Single-file only | Single-file only | Symbolic execution. **Multi-file projects are not currently supported** — mythril's z3 SMT solver consistently OOMs at the 2Gi per-container memory limit on multi-file Hardhat/Foundry projects (verified post-Task #182 fix). Single-file and single-entry-point projects work fully, including Hardhat projects importing `@openzeppelin/contracts/...` (Task #176 — solc Standard JSON remapping via `--solc-json`). Multi-file scans terminate cleanly in one attempt (Task #182 eliminated the prior 4× backoff retry pattern) but fail with `status=failed`. The other 6 Solidity scanners (slither, aderyn, wake, halmos, echidna, medusa) handle multi-file projects fine. Auto-skip on multi-file projects is tracked as Task #183 (post-launch). |
| **Medusa** | Full | Full | Full | Hardhat → Foundry conversion. Note: only finds issues on contracts with property-test invariants. |
| **Securify2** | Full | Limited | Limited | Academic tool, limited project support |

### Feature Support by Scanner

| Scanner | Import Resolution | Remappings | npm Packages | Multi-Contract |
|---------|-------------------|------------|--------------|----------------|
| Slither | Yes | Yes | Yes | Yes |
| Aderyn | Yes | Yes | Limited | Yes |
| SolidityDefend | Yes | Yes | Yes | Yes |
| Echidna | Yes | Yes | Yes | Yes |
| Halmos | Yes | Yes | Yes | Yes |
| Wake | Partial | Partial | Partial | Yes |
| Mythril | Single-file | Single-file | Single-file | Single-file only (Task #182) |

## Foundry Support Details

### Fully Supported Features

- **Configuration Parsing**: `foundry.toml` fully parsed
- **Remappings**: From `foundry.toml` and `remappings.txt`
- **Library Resolution**: `lib/` directory imports
- **Compiler Settings**: Version, optimizer, EVM version
- **Smart Extraction**: Only imported files extracted

### Parsed Configuration Fields

```toml
[profile.default]
src = "src"              # Source directory
test = "test"            # Test directory (excluded)
out = "out"              # Build output (excluded)
libs = ["lib"]           # Library directories
solc = "0.8.20"          # Compiler version
optimizer = true         # Optimizer enabled
optimizer_runs = 200     # Optimizer runs
via_ir = false           # IR compilation
evm_version = "paris"    # EVM target
ffi = false              # FFI enabled
fuzz_runs = 256          # Fuzz iterations
invariant_runs = 256     # Invariant runs
```

### Known Limitations

1. **Forge Scripts**: `script/` directory excluded from scanning
2. **FFI Calls**: Not executed during scanning
3. **Cheatcodes**: Test cheatcodes not available in scans
4. **Build Artifacts**: Not used (contracts compiled fresh)

## Hardhat Support Details

### Fully Supported Features

- **Configuration Parsing**: `hardhat.config.js` parsed (regex-based MVP)
- **npm Dependencies**: Read from `package.json`
- **Import Resolution**: `node_modules/` paths
- **Compiler Settings**: Version, optimizer, EVM version

### Offline Compile (Task #172, 2026-04-26)

The scanner namespace is air-gapped — `npx hardhat compile` cannot reach `binaries.soliditylang.org` to download solc (HH502). All 7 Solidity scanners (slither, aderyn, wake, halmos, mythril, echidna, medusa) convert Hardhat projects to a Foundry-compatible layout at scan time: write a minimal `foundry.toml` with `offline = true` and an explicit OpenZeppelin remapping to `/opt/openzeppelin/v5/`, seed the `.svm` solc cache from pre-installed binaries in the base image, and rename `hardhat.config.*` to `.disabled` so the scanner's compile pipeline (crytic-compile, solcx, forge) picks Foundry framework instead of Hardhat. This is shipped via the slither pass-B fix and the Task #172 sweep PR.

### Pre-Bundled npm Dependencies

| Package | Version | Path | Bundled In |
|---------|---------|------|-----------|
| `@openzeppelin/contracts` | 5.0.2 | `/opt/openzeppelin/v5/` | scanner-base-solidity:1.1.0-b49e3f10 |

OZ 4.x, `@openzeppelin/contracts-upgradeable`, and other libraries (`@chainlink/contracts`, `@uniswap/v3-core`, etc.) are **not** bundled. Projects depending on those will surface `forge build` import errors rather than silently scanning to 0 findings. Reactive bundling on first customer request.

### Parsed Configuration Fields

```javascript
module.exports = {
  solidity: {
    version: "0.8.20",           // Compiler version
    settings: {
      optimizer: {
        enabled: true,            // Optimizer enabled
        runs: 200                 // Optimizer runs
      },
      evmVersion: "paris"         // EVM target
    }
  },
  paths: {
    sources: "./contracts",       // Source directory
    tests: "./test"               // Test directory (excluded)
  }
};
```

### Known Limitations

1. **Complex Configs**: Dynamic/computed configurations may not parse
2. **Multiple Compiler Versions**: Only first version used
3. **Plugin Configuration**: Plugin-specific settings not parsed
4. **TypeScript Configs**: Parsed via regex, complex patterns may fail
5. **Network Configs**: Ignored (deployment settings)

### Future Enhancements (Planned)

- Node.js subprocess parser for full accuracy
- Plugin detection (hardhat-deploy, typechain, upgrades)
- Multi-compiler version support

## Import Resolution

### Foundry Remappings

```solidity
// With remapping: @openzeppelin/=lib/openzeppelin-contracts/
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Resolves to: lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol
```

### Hardhat npm Imports

```solidity
// Resolves from node_modules
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// Resolves to: node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol
```

### Resolution Algorithm

1. Check if import matches a remapping prefix (Foundry)
2. Check if import starts with `@` (npm scoped package)
3. Check relative paths from current file
4. Check library directories (`lib/` or `node_modules/`)

## Tier Limits with Framework Projects

File limits apply **after** smart dependency extraction:

| Tier | Max Files | Typical Project Size |
|------|-----------|---------------------|
| Free | 25 | Small DeFi protocol (5-10 contracts + deps) |
| Pro | 100 | Medium protocol (20-30 contracts + deps) |
| Enterprise | Unlimited | Monorepos, large protocols |

### Smart Extraction Examples

| Project | Total Files | Extracted Files | Fits Tier |
|---------|-------------|-----------------|-----------|
| Simple ERC20 + OZ | 200+ | ~8 | Free |
| DeFi with Uniswap | 500+ | ~45 | Pro |
| Governor + OZ Gov | 200+ | ~25 | Free |
| Full Protocol | 1000+ | ~80 | Pro |

## Best Practices

### For Foundry Projects

1. Define all remappings in `foundry.toml` (not just `remappings.txt`)
2. Use `forge install` to manage dependencies
3. Keep `lib/` directory clean (remove unused packages)
4. Run `forge build` before uploading to verify compilation

### For Hardhat Projects

1. Use `package.json` for all dependencies
2. Run `npm install` before creating archive
3. Use `package-lock.json` for reproducible installs
4. Avoid dynamic configuration in `hardhat.config.js`

### General Recommendations

1. **Exclude test files**: Test directories are automatically excluded
2. **Exclude build artifacts**: Don't include `out/`, `artifacts/`, `cache/`
3. **Check file count**: Use smart extraction to stay within tier limits
4. **Test locally first**: Compile before uploading

## Troubleshooting by Framework

### Foundry Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Import not found | Missing remapping | Add to `foundry.toml` |
| Wrong compiler | Version mismatch | Check `solc` in config |
| Lib not found | Missing submodule | Run `forge install` |

### Hardhat Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Import not found | Missing package | Run `npm install` |
| Config not parsed | Complex config | Simplify config |
| Wrong version | Multiple versions | Use single version |

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Nov 27, 2025 | Initial framework support (Foundry + Hardhat) |
| 1.1.0 | Apr 29, 2026 | Mythril Hardhat+OZ single-file fixed (Task #176); multi-file Hardhat limitation noted (Task #182) |
| 1.2.0 | May 3, 2026 | Mythril multi-file resilience shipped (Task #182, scanner-mythril:0.2.9 — eliminates 4× backoff retry, definitive terminal status in 1 attempt). Multi-file remains explicitly unsupported pending auto-skip implementation (Task #183, post-launch). |
| 1.3.0 | May 3, 2026 | Aderyn and slither Foundry+OZ silent-pass resolved (Task #179). Both wrappers now append `@openzeppelin/contracts/=/opt/openzeppelin/v5/` to `remappings.txt` when OZ imports are detected and no remapping is declared in `foundry.toml`. scanner-aderyn:0.8.4, scanner-slither:0.4.6. The same gap in wake/halmos/echidna/medusa Foundry branches is tracked for follow-up. |
| 1.4.0 | May 4, 2026 | Full scanner re-audit + Task #187 resolution (6 scanners: trident, sol-azy, sec3-xray, cargo-fuzz-solana, rustdefend, semgrep — all now emit singular `error` field on failure so `scan.error_message` is populated). Task #179 sweep extended to wake/echidna/medusa/soliditydefend (remappings.txt). slither/aderyn forge build attribution: non-zero exit now emits `status:failed` rather than silent-continuing on partial AST. scanner-trident:0.4.2, scanner-sol-azy:0.5.1, scanner-sec3-xray:0.4.1, scanner-cargo-fuzz-solana:0.4.2, scanner-rustdefend:0.4.6, scanner-semgrep:0.3.12, scanner-echidna:0.5.4, scanner-medusa:0.4.4, scanner-soliditydefend:0.9.10, scanner-slither:0.4.7, scanner-aderyn:0.8.5. |
| 1.4.1 | May 5, 2026 | Wake target_version regression (Task #192) resolved at scanner-wake:0.5.8. The 1.4.0 wake sweep added `remappings.txt` to wake's Foundry branch but wake's compile pipeline doesn't use `forge build`; the change surfaced wake's solc-list metadata refresh attempt (aiohttp → binaries.soliditylang.org) as a hard NetworkPolicy egress denial. Fix: wake-scan now writes `wake.toml` with `target_version` matching `SOLC_VERSION` (default 0.8.20) so wake uses the seeded `/opt/wake-compilers` cache offline. Verified: Foundry+OZ smoke completed cleanly with real findings, no false-pass. All 17 scanners re-tested cluster-side post-fix; multi-scanner combos and end-to-end review-findings flow verified. |
| 1.4.2 | May 6, 2026 | Six cluster-verified failure modes from the 2026-05-05 production audit fixed. **F1** scanner-trident:0.4.3 — anchor build stdout+stderr captured into BUILD_LOG tempfile, surfaced in error_message (250-char tail, newline-stripped); 3/4 anchor fixtures now show actual `cargo build` errors instead of opaque "Anchor build failed". **F2** scanner-cargo-fuzz-solana:0.4.3 — workspace anchor projects accepted via `find -maxdepth 3 -name Cargo.toml` fallback. **F3** scanner-medusa:0.4.5 — bash heredoc (pre-existing 6.5-month-old bug) replaced with `jq -n --argjson` (echidna pattern); Foundry-no-OZ fixtures no longer hit the EXIT-trap fallback when fuzz vars are empty. **F4** scanner-mythril:0.2.10 — refined `FILE_FAIL_REASON` exit-code mapping (124→timeout, 137→oomkill_${MEM}MB, 1→exit_1_check_pod_logs). **F5** Task #183 implemented: tool-integration:0.6.28 KJM `_should_skip_scanner` auto-skips mythril on multi-file Hardhat projects (z3 SMT structural OOM at 2Gi); fires synthetic `status: "completed"` with `error: <gate-reason>` callback so multi-scanner aggregation continues for slither/wake/etc. **F6** api-service:0.43.6 — `POST /api/v1/contracts/from-github` now validates blob URLs against relative imports (`./X.sol`, `../X.vy`) and returns HTTP 400 `blob_has_relative_imports` with guidance to use a tree URL or archive upload (per `docs/workflows/contract-ingest-workflow.md` design). api-service also now preserves `error` field from completed-with-warning scanner callbacks into `scan.error_message` (companion to F5). All six fixes verified end-to-end against the production API on jasonbrailowbizop@mail.com test account. |

---

**Document Version**: 1.4.2
**Last Updated**: May 6, 2026
