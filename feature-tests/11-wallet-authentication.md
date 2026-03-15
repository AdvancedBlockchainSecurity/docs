# Wallet Authentication Tests (REMOVED)

**Status:** REMOVED in v0.47.0 (March 14, 2026)
**Reason:** Wallet/x402 payment system removed due to 30+ npm vulnerabilities (elliptic, lodash, @walletconnect). Platform uses Stripe-only payments.
**See:** [Security Audit - Wallet Removal](../audit/security-audit-2026-03-14.md)

All wallet authentication (Ethereum MetaMask/WalletConnect, Solana Phantom/Solflare) has been removed from the platform. Authentication is via email/password through Supabase.

Backend wallet endpoints (`/api/v1/auth/wallet/*`, `/api/v1/auth/wallet/solana/*`) remain in the API service code but are non-functional from the frontend.
