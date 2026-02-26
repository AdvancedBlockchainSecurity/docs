# Encryption Standards

**Part of:** [Platform Development Standards](./INDEX.md)
**Version:** 1.0.0
**Last Updated:** February 26, 2026
**Status:** Active

## Overview

Encryption standards for BlockSecOps platform covering data at rest, data in transit, and key management.

---

## 1. Data in Transit

All network communication MUST be encrypted with TLS 1.2+.

| Channel | Protocol | Enforcement |
|---------|----------|-------------|
| Browser to platform | HTTPS (TLS 1.2+) | Traefik terminates TLS; HTTP redirects to HTTPS |
| Service to service (K8s) | mTLS or TLS | NetworkPolicies restrict traffic; services use cluster DNS |
| Service to PostgreSQL | TLS (asyncpg ssl=prefer) | `pg_hba.conf` rejects non-SSL cluster connections (`hostnossl ... reject`) |
| Service to Redis | TLS optional (local), required (production) | `requirepass` for auth; Redis native TLS in production |
| Service to Vault | HTTPS | Vault listener configured with TLS |
| Docker push/pull (Harbor) | HTTPS | Harbor fronted by Traefik with TLS |
| WebSocket (notifications) | WSS | Routed through Traefik `websecure` entrypoint |

### TLS Certificate Management

- **Local:** cert-manager with local CA (`Certificate` resources)
- **Production:** cert-manager with Let's Encrypt (ACME)
- Minimum protocol: TLS 1.2
- Private keys: 0600 permissions, mounted via initContainer from K8s secrets

### PostgreSQL TLS Enforcement

Client-side `ssl=prefer` is supplemented by server-side enforcement via `pg_hba.conf` (`hostnossl ... reject`). The server rejects plaintext connections from cluster IPs. See [Database Management](./database-management.md) for details.

### Prohibited

- Plaintext HTTP for any authenticated endpoint
- Self-signed certificates in production
- TLS 1.0 / 1.1
- Weak cipher suites (RC4, DES, 3DES, export ciphers)

---

## 2. Data at Rest

### Database (PostgreSQL)

| Layer | Method |
|-------|--------|
| Disk encryption | Host-level volume encryption (LUKS on server, GCP PD encryption) |
| Connection auth | Credentials stored in Vault, synced via ExternalSecret |
| Sensitive columns | Application-level encryption for PII (OAuth tokens, MFA secrets) |

Application-level encryption uses Fernet (AES-128-CBC + HMAC-SHA256, via `cryptography` library) with keys stored in Vault at `secret/local/<service>/encryption/key`. New implementations SHOULD prefer AES-256-GCM where the library supports it.

### Object Storage / Backups

- Database backups: compressed (`gzip`) and stored on encrypted volumes
- Production: GCS server-side encryption (Google-managed or CMEK)
- Backup retention: 7 days local, 30 days production

### Secrets (Vault)

- Vault storage backend uses file encryption (local) or Raft with auto-unseal via KMS (production)
- Seal/unseal keys never stored in Git
- Transit secrets engine available for envelope encryption

---

## 3. Key Management

### Key Storage

| Key Type | Storage | Rotation |
|----------|---------|----------|
| JWT signing key (HS256) | Vault `secret/local/<service>/jwt` | On compromise or quarterly |
| Session secret | Vault `secret/local/<service>/session` | On compromise or quarterly |
| Encryption key (AES) | Vault `secret/local/<service>/encryption` | Annually or on compromise |
| TLS private keys | K8s Secret (cert-manager managed) | Auto-renewed before expiry |
| Database credentials | Vault `secret/postgresql` | On compromise |
| API keys (user-facing) | Database (hashed with SHA-256) | User-initiated |

### Key Rotation Procedure

1. Store new key in Vault (versioned KV v2 retains old versions)
2. Update ExternalSecret to sync new key
3. Restart affected service pods
4. Verify service health
5. For encryption keys: re-encrypt data with new key, then purge old version

### JWT Standards

- Algorithm: HS256 (HMAC-SHA256) for service JWTs, RS256 for Supabase Auth
- Minimum key length: 256 bits for HS256
- Tokens MUST include `exp` claim; max lifetime 24 hours for access tokens
- Refresh tokens: stored server-side, rotated on use

### Prohibited

- Hardcoded keys or secrets in source code or Docker images
- Symmetric keys shorter than 128 bits
- RSA keys shorter than 2048 bits
- JWT `none` algorithm or HS256 with public keys (algorithm confusion)
- Sharing keys across environments (local/staging/production)
- Storing plaintext secrets in K8s ConfigMaps or environment variables in manifests

---

## 4. Hashing Standards

| Use Case | Algorithm | Notes |
|----------|-----------|-------|
| Passwords | bcrypt (cost 12) | Via Supabase Auth or `passlib` |
| API key storage | SHA-256 | Keys displayed once at creation, stored as hash |
| Fingerprints (dedup) | SHA-256 | Code, AST, location fingerprints |
| CSRF tokens | `secrets.token_hex(32)` | Cryptographic randomness |
| Temp directories | `secrets.token_hex(16)` or `tempfile.TemporaryDirectory()` | BSO-SEC-362; stdlib `tempfile` uses `os.urandom()` internally and is compliant |

### Prohibited

- MD5 or SHA-1 for any security purpose
- Unsalted hashes for passwords
- `random` module for security-sensitive values (use `secrets`)

---

## 5. Code Review Checklist

Before approving PRs, verify:

- [ ] No plaintext secrets in code, configs, or Docker images
- [ ] TLS used for all external and cross-service communication
- [ ] Encryption keys sourced from Vault, not hardcoded
- [ ] Passwords hashed with bcrypt, never stored in plaintext
- [ ] `secrets` module used for all security-sensitive random values
- [ ] Sensitive data encrypted at the application level where required

---

## Related Documentation

- [Secrets Management](./secrets-management.md) — Vault and ExternalSecret workflow
- [Security Standards](./security-standards.md) — Circuit breakers, archive security, SQL auth
- [Secure Coding Standards](./secure-coding.md) — OWASP Top 10 prevention
- [Database Management](./database-management.md) — PostgreSQL TLS, backup procedures
