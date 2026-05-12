# Workflow — Upload a contract with pre-compiled artifacts

**Audience:** end users uploading Foundry / Hardhat / Anchor projects to Apogee
**Status:** active (Migration 091, 2026-05-09)
**Cross-links:** [Pipeline](../pipelines/artifact-aware-scan-dispatch.md), [Playbook: troubleshoot fuzzer 0 findings](../playbooks/troubleshoot-fuzzer-zero-findings.md)

---

## Why this matters

Halmos, Echidna, Medusa, and Trident depend on **pre-compiled build outputs** to find real vulnerabilities. When the scanner pod has to rebuild your project on the cluster:

- Foundry: `forge build` fails silently if `forge-std`/`@openzeppelin/contracts` aren't bundled.
- Hardhat: `npx hardhat compile` needs internet for `solc` downloads (NetworkPolicy blocks it).
- Anchor: `anchor build` requires the full Solana toolchain (~5 minutes if it succeeds at all).

When the build fails, the scanner reports **0 findings** as if your project were clean — even when it isn't. Pre-compiling locally and uploading the artifacts (`out/`, `artifacts/`, `target/idl/`) eliminates that failure mode.

---

## When to enable "Include pre-compiled artifacts"

| Your project | Enable the toggle? |
|---|---|
| Foundry project + you want Halmos/Echidna/Medusa to run | **Yes** — include `out/` from `forge build` |
| Hardhat project + you want Echidna/Medusa to run | **Yes** — include `artifacts/` and `cache/` from `npx hardhat compile` |
| Anchor project + you want Trident to run | **Yes** — include `target/idl/` from `anchor build` |
| Single Solidity / Vyper / Rust file | The toggle is hidden — single-file uploads only run static analyzers |
| Plain multi-file (no recognized config) | Leave unchecked — only static analyzers will run |

You can re-upload the same project later with the toggle enabled if you initially skipped it.

---

## How to prepare your archive

### Foundry

```bash
# 1. Build locally so you know it compiles
forge build

# 2. Bundle source + out/
tar -czf project.tgz \
  src/ test/ script/ lib/ \
  foundry.toml remappings.txt \
  out/

# 3. Upload via the dashboard, toggle ON
```

Skip `out/build-info/` if you want to keep the archive small — Halmos / Echidna / Medusa only need the per-contract JSONs at `out/<File>.sol/<Contract>.json`.

### Hardhat

```bash
# 1. Compile locally
npx hardhat compile

# 2. Bundle source + artifacts/ + cache/
tar -czf project.tgz \
  contracts/ test/ scripts/ \
  hardhat.config.* package.json \
  artifacts/ cache/solidity-files-cache.json

# 3. Upload via the dashboard, toggle ON
```

### Anchor

```bash
# 1. Build locally (generates target/idl/<program>.json)
anchor build

# 2. Bundle source + target/idl/
tar -czf project.tgz \
  programs/ tests/ \
  Anchor.toml Cargo.toml Cargo.lock \
  target/idl/

# 3. Upload via the dashboard, toggle ON
```

**Do NOT include `target/deploy/`** — that contains your program keypair (private signing key). The platform actively rejects archives with `target/deploy/`-style secrets; even if you bundle them, they'll be stripped server-side before reaching any scanner.

---

## Limits & validation

- **Max total artifact size:** 200 MB (per archive)
- **Max artifact files:** 5,000
- **Allow-list:** only `.json` files inside `out/`, `artifacts/`, or `target/idl/` are kept. Binaries (`.so`, `.bin`, `.exe`) and Anchor program keypairs are rejected.
- **Per-file size cap:** 10 MB
- The archive itself still has to pass the standard upload checks (CWE-22 path-traversal, CWE-409 zip-bomb ratio ≤ 10:1, CWE-61 no symlinks/hardlinks).

If the archive exceeds the artifact caps, the upload returns **HTTP 413** with a friendly error. If the user enables the toggle but no recognized layout (`out/`, `artifacts/contracts/`, `target/idl/`) is found, the upload returns **HTTP 400** with the framework-specific bundling guidance.

---

## What the dashboard shows after upload

- **Pre-compiled ✓** chip on the contract-detail header — confirms the artifacts were preserved.
- **Source only** chip on contracts uploaded without the toggle — note that fuzzers may report 0 findings on missing-dep projects.
- An amber soft warning on the scanner picker if you select Halmos/Echidna/Medusa/Trident on a Source-only contract — recommends re-uploading with artifacts.

---

## Authorization & tier

The `with_artifacts` flag does not widen your existing endpoint scope. The standard `contracts:write` permission is required (same as any upload). No new tier gate is enforced today; the platform-wide cap (200 MB) applies to all tiers.

---

## Troubleshooting

If a fuzzer reports 0 findings and you expected ≥ 1, see [`docs/playbooks/troubleshoot-fuzzer-zero-findings.md`](../playbooks/troubleshoot-fuzzer-zero-findings.md).
