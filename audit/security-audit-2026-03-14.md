# Security Audit — 2026-03-14

## Scope

Platform-wide audit against docs/standards/. Covers codebase, Kustomize, images, database, ports, auth, secrets, encryption, versioning, and dependency vulnerabilities.

## Findings & Remediation

### Kustomize
- blocksecops-shared: `includeSelectors: true` in 3 overlays — fixed to `false`

### Dependencies (CVEs fixed)

**Python (system)**: urllib3, wheel, cryptography, jaraco-context, pip, protobuf, pyjwt upgraded. python-jose + ecdsa removed (unused).

**Rust**: bytes upgraded (contract-parser), pyo3 0.22→0.24 (shared).

**JavaScript**: axios fixed (admin-portal). Dashboard wallet dependencies removed (see below).

### Wallet/x402 Removal (dashboard 0.47.0)

30+ npm vulnerabilities traced to WalletConnect, @toruslabs, @trezor, elliptic (no upstream fix). Removed all wallet and x402 crypto payment dependencies. Stripe remains the only payment method. Email/OAuth remains the only auth method.

Removed: wagmi, viem, @solana/wallet-adapter-*, @solana/web3.js, WalletConnectButton, SolanaConnectButton, WalletSettings, Web3Provider, SolanaProvider, x402 USDC payment flow.

npm audit result after removal: 0 high, 0 moderate, 6 low (elliptic in vite-plugin-node-polyfills build tool — not shipped to users).

### UI Style Guide Compliance (dashboard 0.47.0)

- ScanListTable severity badges: now use style guide colors (error/#FF3366, warning/#FF8A00, yellow-400, electric/#00D4FF)
- Modal cancel/secondary buttons: fixed unreadable white/gray on dark background in PaymentModal, QuotaExceededModal, BatchScanModal, ContractUploadModal, TierChangeModal, CreateApiKeyModal

## Services Verified

All 15 platform pods running. API healthy. Contract parser healthy. Scanner jobs run on GCP Spot VM node pool.
