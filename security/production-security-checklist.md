# Production Security Checklist

**Purpose:** Comprehensive security validation checklist for production deployment of the BlockSecOps Platform.

**Last Updated:** December 28, 2025
**Status:** Pre-Production Review (Phase 7A Security Hardening Complete)

---

## 🔴 Critical Priority (P0) - Must Complete Before Production

### Authentication & Authorization

- [ ] **HttpOnly Cookies Implemented**
  - JWT tokens stored in HttpOnly cookies (not localStorage)
  - Cookies set with `httponly`, `secure`, `samesite=strict` flags
  - JavaScript cannot access tokens via `document.cookie` or `localStorage`
  - Verified in browser DevTools

- [ ] **Refresh Token Rotation**
  - New refresh token issued on each refresh request
  - Old refresh token immediately invalidated
  - Token reuse detection implemented
  - All user sessions revoked on token reuse detection
  - Session tracking table includes refresh_count, is_revoked fields

- [ ] **HTTPS Enforcement**
  - All HTTP traffic redirects to HTTPS
  - TLS 1.2+ enforced (TLS 1.0/1.1 disabled)
  - HSTS header set with `max-age=31536000; includeSubDomains; preload`
  - SSL/TLS certificates valid and auto-renewing (Let's Encrypt)
  - No mixed content warnings in browser

- [x] **Security Headers** ✅ (Phase 7A - December 2025)
  - `Strict-Transport-Security` header set (production only)
  - `X-Content-Type-Options: nosniff` header set
  - `X-Frame-Options: DENY` header set
  - `X-XSS-Protection: 1; mode=block` header set
  - `Content-Security-Policy` configured (Dashboard production overlay)
  - `Referrer-Policy: strict-origin-when-cross-origin` configured
  - `Permissions-Policy` configured (geolocation, microphone, camera, payment, usb)
  - `Cache-Control: no-store, max-age=0` configured
  - Middleware: `SecurityHeadersMiddleware` in API service
  - Verified with curl tests (see feature-tests/28-webapp-security.md)

### Secrets Management

- [ ] **HashiCorp Vault Integration**
  - External Secrets Operator installed
  - Vault policies configured for each service
  - SecretStore resources created
  - ExternalSecret resources deployed
  - All secrets migrated from Kubernetes secrets to Vault
  - No secrets committed to Git repositories
  - Secret rotation automation configured

- [ ] **Database Credentials**
  - PostgreSQL password stored in Vault (not k8s secret)
  - Strong password (64+ characters, generated)
  - Connection string includes `sslmode=require`
  - Dedicated service accounts per application
  - No shared database passwords

- [ ] **API Keys & Tokens**
  - JWT secret key stored in Vault (256+ bits entropy)
  - Session secret stored in Vault
  - Redis password stored in Vault
  - Blockchain RPC API keys stored in Vault
  - AWS credentials stored in Vault (if applicable)

### Infrastructure Security

- [ ] **Network Policies**
  - NetworkPolicy resources deployed for all namespaces
  - Default deny-all policy in production namespace
  - API service only accepts ingress from ingress controller
  - API service egress limited to PostgreSQL, Redis, DNS
  - Database only accepts connections from API service
  - Redis only accepts connections from API service
  - No pod can access kube-system namespace

- [ ] **Pod Security Standards**
  - Production namespace enforces `restricted` Pod Security Standard
  - All pods run as non-root user (`runAsNonRoot: true`)
  - All pods have `readOnlyRootFilesystem: true`
  - All pods drop all capabilities (`drop: [ALL]`)
  - All pods have `allowPrivilegeEscalation: false`
  - All pods use seccomp profile (`type: RuntimeDefault`)

- [ ] **Database TLS Encryption**
  - PostgreSQL configured for TLS connections
  - Database URL includes `sslmode=require`
  - SSL certificate verification enabled
  - SQLAlchemy connection uses SSL context
  - Connection test passes with TLS

- [ ] **Container Image Security**
  - All images from trusted registries
  - Images scanned for vulnerabilities (Trivy/Snyk)
  - No critical or high vulnerabilities in images
  - Images signed and verified
  - Latest base image patches applied

---

## 🟠 High Priority (P1) - Should Complete for Production Launch

### API Security

- [ ] **Input Validation**
  - All endpoints use Pydantic models for validation
  - Ethereum addresses validated with regex
  - Network names validated (whitelist)
  - File upload validation (size, type, content)
  - Text inputs sanitized (HTML/JavaScript stripped)
  - SQL injection prevention verified
  - XSS prevention verified
  - Command injection prevention verified

- [ ] **Rate Limiting**
  - slowapi rate limiter installed
  - Redis backend for distributed rate limiting
  - Authentication endpoints: 5 requests/minute
  - Contract analysis endpoints: 10 requests/minute per user
  - Read endpoints: 100-200 requests/minute per user
  - Rate limit headers included in responses
  - 429 Too Many Requests response tested

- [x] **CORS Configuration** ✅ (Phase 7A - December 2025)
  - Strict origin whitelist (configurable via cors_origins setting)
  - `allow_credentials: true` for cookie support
  - Allowed methods limited: GET, POST, PUT, PATCH, DELETE, OPTIONS
  - Allowed headers limited: Authorization, Content-Type, X-Request-ID, X-API-Key, Accept, Origin
  - Expose headers: X-Request-ID
  - Development CORS separate from production (via configmap)

- [ ] **Request/Response Logging**
  - All API requests logged with context
  - User ID included in logs (when authenticated)
  - IP address and User-Agent logged
  - Request ID generated and tracked
  - Response status and duration logged
  - Sensitive data not logged (passwords, tokens)
  - Structured JSON logging format
  - Log aggregation configured (Loki/CloudWatch)

### Web Application Firewall (WAF)

- [ ] **WAF Deployment**
  - AWS WAF / Cloudflare WAF configured
  - OWASP ModSecurity Core Rule Set enabled
  - SQL injection rules enabled
  - XSS rules enabled
  - Bot protection enabled
  - Rate limiting at WAF level
  - Geo-blocking configured (if applicable)

### Data Security

- [ ] **Redis Security**
  - Redis authentication enabled (`requirepass`)
  - Redis TLS encryption enabled
  - Dangerous commands disabled (FLUSHALL, CONFIG, etc.)
  - Redis network policy restricts access
  - Connection pooling configured
  - Max memory limit set with eviction policy

### Monitoring & Alerting

- [ ] **Security Monitoring**
  - Failed authentication attempts tracked
  - Rate limit violations tracked
  - Suspicious API patterns detected
  - Database connection failures alerted
  - Vault secret access monitored
  - Security dashboard in Grafana

- [ ] **Alert Configuration**
  - Slack/PagerDuty integration configured
  - Critical alerts trigger immediate notification
  - On-call rotation established
  - Alert fatigue prevention (proper thresholds)
  - Weekly security report automation

---

## 🟡 Medium Priority (P2) - Complete Within 2-4 Weeks

### Backup & Disaster Recovery

- [ ] **Automated Backups**
  - Daily PostgreSQL backups configured
  - Backup CronJob running successfully
  - Backups uploaded to S3 (or equivalent)
  - Backup encryption enabled
  - Retention policy configured (30 days → Glacier → 90 days delete)
  - Backup restoration tested successfully
  - Point-in-time recovery capability verified
  - Backup monitoring alerts configured

- [ ] **Disaster Recovery Plan**
  - RPO (Recovery Point Objective) defined
  - RTO (Recovery Time Objective) defined
  - Database restore procedure documented
  - Service restore procedure documented
  - Disaster recovery drill completed
  - Offsite backup storage configured

### Operational Security

- [ ] **Incident Response**
  - Incident response playbook created
  - Emergency contact list maintained
  - Severity classification defined
  - Escalation procedures documented
  - Breach notification procedures (GDPR compliance)
  - Forensics data collection procedures
  - Quarterly tabletop exercises conducted

- [ ] **Audit Logging**
  - All authentication events logged
  - Admin actions logged
  - Sensitive data access logged
  - Configuration changes logged
  - Logs immutable (write-once storage)
  - Log retention policy defined (1 year minimum)

- [ ] **Dependency Scanning**
  - Snyk or Dependabot configured
  - Weekly dependency scans automated
  - GitHub Security Alerts enabled
  - Automated PRs for security updates
  - Pre-commit hooks for secret detection
  - SBOM (Software Bill of Materials) generated

### Access Control

- [ ] **Service Accounts**
  - Kubernetes ServiceAccounts for each service
  - RBAC roles with least privilege
  - No pods use default ServiceAccount
  - Service account token auto-mounting disabled (when not needed)

- [ ] **Admin Access**
  - kubectl access requires VPN
  - Multi-factor authentication for admin users
  - Admin actions logged
  - Separate admin accounts (no shared passwords)
  - Regular access review (quarterly)

---

## 🟢 Low Priority (P3) - Advanced Security (Month 2+)

### Advanced Authentication

- [ ] **Multi-Factor Authentication (2FA/MFA)**
  - TOTP-based 2FA implemented
  - Backup codes generated
  - SMS fallback configured
  - 2FA required for admin users
  - 2FA recovery process documented

- [ ] **CAPTCHA Integration**
  - reCAPTCHA on login page
  - reCAPTCHA on registration page
  - CAPTCHA on password reset
  - Invisible CAPTCHA for low-friction UX

- [ ] **Device Tracking**
  - Device fingerprinting enabled
  - New device alerts sent to users
  - Suspicious login location detection
  - Device management UI (trust/revoke devices)

### Compliance & Auditing

- [ ] **GDPR Compliance**
  - Privacy policy published
  - Cookie consent banner
  - Data export functionality
  - Data deletion functionality
  - Data processing agreement (DPA)
  - Right to be forgotten implementation

- [ ] **SOC 2 Compliance** (if applicable)
  - Security policies documented
  - Access controls audited
  - Change management process
  - Vendor risk assessment
  - Annual SOC 2 audit

- [ ] **Security Audits**
  - External penetration testing (annually)
  - Code security review (quarterly)
  - Infrastructure security review (quarterly)
  - Compliance audit (annually)

### Service Mesh (Advanced)

- [ ] **Service Mesh Deployment** (Istio/Linkerd)
  - mTLS between all services
  - Service-to-service authentication
  - Fine-grained authorization policies
  - Traffic encryption
  - Observability integration

### Hardware Security

- [ ] **HSM Integration** (if storing private keys)
  - Hardware Security Module provisioned
  - Private key generation in HSM
  - Transaction signing via HSM
  - Key backup and recovery procedures
  - HSM failover tested

---

## Testing & Validation

### Security Testing Tools

- [ ] **OWASP ZAP Scan**
  - Automated scan configured in CI/CD
  - No high/critical vulnerabilities reported
  - False positives documented

- [ ] **Burp Suite Pro**
  - Manual penetration testing completed
  - Vulnerability report reviewed
  - All findings remediated or accepted

- [ ] **Nmap Port Scan**
  - Only required ports open (80, 443)
  - Database ports not accessible externally
  - Redis ports not accessible externally
  - No unexpected services exposed

### Manual Security Tests

- [ ] **Authentication Security**
  ```bash
  # Test XSS protection
  localStorage.getItem('access_token')  # Should be null
  document.cookie  # Should not show tokens

  # Test HTTPS redirect
  curl -I http://api.soliditysecurity.com  # Should 301 to HTTPS

  # Test rate limiting
  for i in {1..10}; do curl -X POST https://api.soliditysecurity.com/api/v1/auth/login; done
  ```

- [ ] **SQL Injection Test**
  ```bash
  # Test input validation
  curl -X POST https://api.soliditysecurity.com/api/v1/contracts/analyze \
    -d '{"contract_address": "0x1234'; DROP TABLE users; --"}'
  # Should return 422 Validation Error
  ```

- [ ] **XSS Test**
  ```bash
  # Test script injection
  curl -X POST https://api.soliditysecurity.com/api/v1/comments \
    -d '{"content": "<script>alert('XSS')</script>"}'
  # Should be sanitized
  ```

- [ ] **CSRF Test**
  - Attempt cross-origin request without credentials
  - Should be blocked by CORS policy

---

## Environment-Specific Checklists

### Local Development ✅
- [x] Uses mock secrets (not production secrets)
- [x] HTTPS optional (development certificates)
- [x] CORS allows localhost origins
- [x] Rate limiting disabled or very permissive
- [x] Debug logging enabled

### Staging ⏳
- [ ] Mirrors production security configuration
- [ ] Uses separate secrets (not production secrets)
- [ ] HTTPS enforced
- [ ] Network policies enabled
- [ ] Full security testing completed

### Production 🔴
- [ ] All P0 (Critical) items completed
- [ ] All P1 (High) items completed
- [ ] Security audit passed
- [ ] Penetration testing completed
- [ ] Compliance requirements met
- [ ] Incident response plan tested
- [ ] Monitoring and alerting verified
- [ ] Backup/recovery tested

---

## Sign-off Requirements

### Before Production Deployment

- [ ] **Security Team Approval**
  - Name: ________________
  - Date: ________________
  - Signature: ________________

- [ ] **Platform Lead Approval**
  - Name: ________________
  - Date: ________________
  - Signature: ________________

- [ ] **Compliance Team Approval** (if applicable)
  - Name: ________________
  - Date: ________________
  - Signature: ________________

---

## References

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [JWT Best Practices (RFC 8725)](https://datatracker.ietf.org/doc/html/rfc8725)

---

## Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-06 | Security Team | Initial checklist creation |
| 1.1 | 2025-12-28 | Claude Code | Phase 7A: Security Headers, CORS, Request Size Limit implemented |

---

**Next Review Date:** Before production deployment
**Review Frequency:** Quarterly after production launch
