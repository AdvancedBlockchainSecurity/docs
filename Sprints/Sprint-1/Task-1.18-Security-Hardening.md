# Task 1.18: Production Security Hardening - Implementation Details

**✅ ALIGNMENT CHECK**: This task provides comprehensive security hardening for production deployment, addressing authentication security, infrastructure security, and operational security as required for production readiness.

## High-Level Objectives

### Primary Goal
Implement comprehensive security hardening across all platform components to ensure production-ready security posture, addressing authentication, infrastructure, network, and operational security requirements.

### Key Requirements
- **Authentication Security**: HttpOnly cookies, token rotation, HTTPS enforcement
- **Infrastructure Security**: Secrets management, network policies, pod security standards
- **API Security**: Input validation, rate limiting, CORS, security headers
- **Data Security**: Encryption at rest, database TLS, Redis security
- **Operational Security**: Logging, monitoring, incident response, backup/recovery

## Standards Reference
- **Security Best Practices**: Follow OWASP Top 10 guidelines and security standards defined in `docs/security/authentication-security.md`
- **Dependency Versions**: Always use the latest stable versions of all security-related dependencies
- **Secret Management**: All secrets must be stored in HashiCorp Vault and synchronized using External Secrets Operator
- **Network Security**: Implement zero-trust network policies as defined in Kubernetes security standards

## Priority Classification

### 🔴 P0 - Critical (Week 1 - Before Production)
Must be completed before any production deployment. Security vulnerabilities that could lead to data breaches or system compromise.

### 🟠 P1 - High (Week 2 - Production Launch)
Should be completed for production launch. Significant security improvements that reduce attack surface.

### 🟡 P2 - Medium (Week 3-4 - Post-Launch Hardening)
Important security enhancements for defense-in-depth strategy.

### 🟢 P3 - Low (Month 2+ - Advanced Security)
Long-term security improvements and compliance requirements.

---

## Step 1: Authentication Security Hardening (4 hours) 🔴 P0

### Objectives
- Implement HttpOnly cookies for JWT storage
- Add refresh token rotation with reuse detection
- Enforce HTTPS-only communication
- Configure security headers

### 1.1 HttpOnly Cookies Implementation

**Repository:** `solidity-security-api-service`

**Backend Changes (`src/presentation/api/v1/endpoints/auth.py`):**
```python
from fastapi import Response, Request, HTTPException

@router.post("/auth/login")
async def login(
    response: Response,
    credentials: LoginRequest,
    handler: AuthHandler = Depends(get_auth_handler)
):
    """Login with HttpOnly cookie authentication"""
    # Authenticate user
    user, access_token, refresh_token = await handler.login(credentials)

    # Set HttpOnly cookies instead of returning in body
    response.set_cookie(
        key="access_token",
        value=access_token,
        httponly=True,      # Prevents JavaScript access (XSS protection)
        secure=True,        # HTTPS only
        samesite="strict",  # CSRF protection
        max_age=1800,       # 30 minutes
        path="/api"         # Limit cookie scope
    )

    response.set_cookie(
        key="refresh_token",
        value=refresh_token,
        httponly=True,
        secure=True,
        samesite="strict",
        max_age=604800,     # 7 days
        path="/api/v1/auth/refresh"  # Only sent to refresh endpoint
    )

    return {
        "message": "Login successful",
        "user": {
            "id": user.id,
            "email": user.email,
            "is_active": user.is_active
        }
    }

@router.post("/auth/logout")
async def logout(response: Response):
    """Logout by clearing cookies"""
    response.delete_cookie(key="access_token", path="/api")
    response.delete_cookie(key="refresh_token", path="/api/v1/auth/refresh")
    return {"message": "Logout successful"}
```

**JWT Dependency Update (`src/infrastructure/security/jwt.py`):**
```python
from fastapi import Request, HTTPException, status

async def get_current_user_from_cookie(
    request: Request,
    db: AsyncSession = Depends(get_db)
) -> User:
    """Extract JWT from HttpOnly cookie"""
    token = request.cookies.get("access_token")
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated"
        )

    try:
        payload = decode_token(token)
        user = await db.get(User, payload["user_id"])
        if not user or not user.is_active:
            raise HTTPException(status_code=401, detail="Invalid user")
        return user
    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

**Frontend Changes (`solidity-security-dashboard/src/lib/api/client.ts`):**
```typescript
// Remove localStorage token management
const apiClient = axios.create({
  baseURL: API_BASE_URL,
  withCredentials: true,  // Send cookies with requests
});

// Remove Authorization header injection (cookies handled automatically)
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    // No manual token injection needed - cookies sent automatically
    return config;
  }
);

// Update refresh logic to use cookie-based refresh
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    if (error.response?.status === 401 && !originalRequest._retry) {
      originalRequest._retry = true;
      try {
        // Call refresh endpoint (refresh_token sent via cookie)
        await apiClient.post('/auth/refresh');
        // Retry original request with new access_token cookie
        return apiClient(originalRequest);
      } catch (refreshError) {
        // Redirect to login on refresh failure
        window.location.href = '/login';
        return Promise.reject(refreshError);
      }
    }
    return Promise.reject(error);
  }
);
```

**Update AuthContext (`solidity-security-dashboard/src/contexts/AuthContext.tsx`):**
```typescript
// Remove localStorage token management
export function AuthProvider({ children }: AuthProviderProps) {
  const login = async (data: LoginRequest) => {
    // POST to /auth/login - cookies set automatically by server
    const response = await authApi.login(data);
    setUser(response.user);  // Only store user data, not tokens
  };

  const logout = async () => {
    await authApi.logout();  // Server clears cookies
    setUser(null);
  };

  // Remove all localStorage.getItem/setItem calls for tokens
}
```

**Deliverables:**
- [ ] Backend login endpoint sets HttpOnly cookies
- [ ] Backend refresh endpoint validates and rotates cookies
- [ ] Backend logout endpoint clears cookies
- [ ] JWT dependency extracts token from cookies
- [ ] Frontend removes localStorage token management
- [ ] Frontend sends cookies with `withCredentials: true`
- [ ] AuthContext updated to remove token storage

**Testing:**
```bash
# Verify cookies are set
curl -X POST http://localhost:8001/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}' \
  -v  # Should show Set-Cookie headers with httponly flag

# Verify JavaScript cannot access cookies (browser console)
document.cookie  # Should not show access_token or refresh_token
localStorage.getItem('access_token')  # Should be null
```

---

### 1.2 Refresh Token Rotation

**Database Migration (`alembic/versions/xxx_add_session_tracking.py`):**
```python
def upgrade():
    op.add_column('sessions', sa.Column('refresh_count', sa.Integer, default=0))
    op.add_column('sessions', sa.Column('is_revoked', sa.Boolean, default=False))
    op.add_column('sessions', sa.Column('last_refresh_at', sa.DateTime, nullable=True))
    op.add_column('sessions', sa.Column('ip_address', sa.String(45), nullable=True))
    op.add_column('sessions', sa.Column('user_agent', sa.String(255), nullable=True))
```

**Refresh Endpoint (`src/presentation/api/v1/endpoints/auth.py`):**
```python
@router.post("/auth/refresh")
async def refresh_token(
    request: Request,
    response: Response,
    db: AsyncSession = Depends(get_db)
):
    """Refresh token with rotation and reuse detection"""
    refresh_token = request.cookies.get("refresh_token")
    if not refresh_token:
        raise HTTPException(status_code=401, detail="No refresh token")

    try:
        payload = decode_token(refresh_token)
        session_id = payload.get("session_id")

        # Check if token already used (rotation detection)
        session = await db.get(SessionModel, session_id)
        if not session or session.is_revoked or session.refresh_count > 0:
            # Token reuse detected - possible attack
            await revoke_all_user_sessions(db, payload["user_id"])
            raise HTTPException(
                status_code=401,
                detail="Token reuse detected - all sessions revoked"
            )

        # Create new tokens
        new_access_token = create_access_token(payload["user_id"])
        new_refresh_token = create_refresh_token(payload["user_id"])

        # Invalidate old refresh token
        session.is_revoked = True
        session.refresh_count += 1
        session.last_refresh_at = datetime.utcnow()
        await db.commit()

        # Create new session
        new_session = SessionModel(
            user_id=payload["user_id"],
            token=new_access_token,
            refresh_token=new_refresh_token,
            ip_address=request.client.host,
            user_agent=request.headers.get("user-agent")
        )
        db.add(new_session)
        await db.commit()

        # Set new cookies
        response.set_cookie(
            key="access_token",
            value=new_access_token,
            httponly=True,
            secure=True,
            samesite="strict",
            max_age=1800
        )

        response.set_cookie(
            key="refresh_token",
            value=new_refresh_token,
            httponly=True,
            secure=True,
            samesite="strict",
            max_age=604800
        )

        return {"message": "Token refreshed successfully"}

    except JWTError:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

async def revoke_all_user_sessions(db: AsyncSession, user_id: str):
    """Revoke all sessions for a user (security breach response)"""
    await db.execute(
        update(SessionModel)
        .where(SessionModel.user_id == user_id)
        .values(is_revoked=True)
    )
    await db.commit()
```

**Deliverables:**
- [ ] Database migration adds session tracking fields
- [ ] Refresh endpoint implements token rotation
- [ ] Token reuse detection implemented
- [ ] Automatic session revocation on suspicious activity
- [ ] IP address and user agent tracking

---

### 1.3 HTTPS Enforcement

**FastAPI Middleware (`src/main.py`):**
```python
from starlette.middleware.httpsredirect import HTTPSRedirectMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware

if settings.environment == "production":
    # Redirect HTTP to HTTPS
    app.add_middleware(HTTPSRedirectMiddleware)

    # Only allow requests from trusted hosts
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=[
            "api.soliditysecurity.com",
            "*.soliditysecurity.com"
        ]
    )

# Security headers middleware
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)

    # HSTS - Force HTTPS for 1 year
    response.headers["Strict-Transport-Security"] = \
        "max-age=31536000; includeSubDomains; preload"

    # Prevent MIME sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"

    # Prevent clickjacking
    response.headers["X-Frame-Options"] = "DENY"

    # XSS protection (legacy browsers)
    response.headers["X-XSS-Protection"] = "1; mode=block"

    # Content Security Policy
    response.headers["Content-Security-Policy"] = \
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'"

    # Referrer policy
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"

    # Permissions policy
    response.headers["Permissions-Policy"] = \
        "geolocation=(), microphone=(), camera=()"

    return response
```

**Kubernetes Ingress (`k8s/base/api-service/ingress.yaml`):**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-service-ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/ssl-ciphers: "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - api.soliditysecurity.com
    secretName: api-tls-cert
  rules:
  - host: api.soliditysecurity.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-service
            port:
              number: 8000
```

**Deliverables:**
- [ ] HTTPS redirect middleware for production
- [ ] Security headers middleware implemented
- [ ] Ingress configured with TLS/SSL
- [ ] Let's Encrypt certificate automation
- [ ] HSTS preload configured

**Estimated Time:** 4 hours
**Dependencies:** None
**Risk Level:** Medium (requires careful testing to avoid breaking auth)

---

## Step 2: Infrastructure Security (6 hours) 🔴 P0

### Objectives
- Migrate secrets to HashiCorp Vault
- Implement Kubernetes NetworkPolicies
- Enforce Pod Security Standards
- Enable database TLS encryption

### 2.1 HashiCorp Vault Integration

**Install External Secrets Operator:**
```bash
# Add Helm repository
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install operator
helm install external-secrets \
  external-secrets/external-secrets \
  -n external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

**Vault Configuration (`vault/policies/api-service-policy.hcl`):**
```hcl
# Policy for API service to read secrets
path "secret/data/api-service/*" {
  capabilities = ["read"]
}

path "secret/data/database/*" {
  capabilities = ["read"]
}

path "secret/data/jwt/*" {
  capabilities = ["read"]
}
```

**SecretStore Configuration (`k8s/base/api-service/secretstore.yaml`):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: api-service-prod
spec:
  provider:
    vault:
      server: "https://vault.soliditysecurity.com"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "api-service"
          serviceAccountRef:
            name: api-service
```

**ExternalSecret (`k8s/base/api-service/externalsecret.yaml`):**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: api-service-secret
  namespace: api-service-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: api-service-secret
    creationPolicy: Owner
  data:
  - secretKey: DATABASE_URL
    remoteRef:
      key: secret/database/api-service
      property: url
  - secretKey: REDIS_URL
    remoteRef:
      key: secret/redis/api-service
      property: url
  - secretKey: JWT_SECRET_KEY
    remoteRef:
      key: secret/jwt/api-service
      property: secret_key
  - secretKey: SESSION_SECRET
    remoteRef:
      key: secret/session/api-service
      property: secret
```

**Seed Vault with Secrets:**
```bash
# Enable KV secrets engine
vault secrets enable -path=secret kv-v2

# Store database credentials
vault kv put secret/database/api-service \
  url="postgresql+asyncpg://solidity:STRONG_PASSWORD@postgresql.postgresql-prod.svc.cluster.local:5432/solidity_security?sslmode=require"

# Store Redis credentials
vault kv put secret/redis/api-service \
  url="rediss://redis-master.redis-prod.svc.cluster.local:6380/0"

# Store JWT secret
vault kv put secret/jwt/api-service \
  secret_key="$(openssl rand -base64 64)"

# Store session secret
vault kv put secret/session/api-service \
  secret="$(openssl rand -base64 32)"
```

**Deliverables:**
- [ ] External Secrets Operator installed
- [ ] Vault policies configured
- [ ] SecretStore and ExternalSecret created
- [ ] Secrets migrated from k8s secrets to Vault
- [ ] Secret rotation automation configured

---

### 2.2 Network Policies

**API Service Network Policy (`k8s/base/api-service/networkpolicy.yaml`):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-service-netpol
  namespace: api-service-prod
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: api-service
  policyTypes:
  - Ingress
  - Egress

  # Ingress: Only allow from ingress controller
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
      podSelector:
        matchLabels:
          app.kubernetes.io/name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8000

  # Egress: Allow DNS, PostgreSQL, Redis only
  egress:
  # DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53

  # PostgreSQL
  - to:
    - namespaceSelector:
        matchLabels:
          name: postgresql-prod
      podSelector:
        matchLabels:
          app.kubernetes.io/name: postgresql
    ports:
    - protocol: TCP
      port: 5432

  # Redis
  - to:
    - namespaceSelector:
        matchLabels:
          name: redis-prod
      podSelector:
        matchLabels:
          app.kubernetes.io/name: redis
    ports:
    - protocol: TCP
      port: 6380

  # HTTPS for external APIs (blockchain RPCs)
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
```

**Default Deny Policy (`k8s/base/api-service/default-deny.yaml`):**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: api-service-prod
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

**Deliverables:**
- [ ] Network policies deployed for all services
- [ ] Default deny-all policy in production namespace
- [ ] Ingress-only access to API service
- [ ] Egress limited to required services only

---

### 2.3 Pod Security Standards

**Namespace Security (`k8s/overlays/production/namespace.yaml`):**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: api-service-prod
  labels:
    # Enforce restricted pod security standard
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

**Pod Security Context (Already configured - verify):**
```yaml
# Verify deployment.yaml has these settings
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault

containers:
- name: api-service
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
```

**Deliverables:**
- [ ] Production namespace enforces restricted PSS
- [ ] All deployments comply with restricted standard
- [ ] Audit logging enabled for policy violations

---

### 2.4 Database TLS Encryption

**PostgreSQL TLS Configuration:**
```yaml
# k8s/base/postgresql/values-override.yaml
postgresql:
  tls:
    enabled: true
    certificatesSecret: postgresql-tls-cert
    certFilename: tls.crt
    certKeyFilename: tls.key
    certCAFilename: ca.crt
```

**Update Database URL:**
```bash
# Update Vault secret with sslmode=require
vault kv put secret/database/api-service \
  url="postgresql+asyncpg://solidity:PASSWORD@postgresql.postgresql-prod.svc:5432/solidity_security?sslmode=require"
```

**SQLAlchemy SSL Configuration (`src/infrastructure/database/connection.py`):**
```python
import ssl

# Create SSL context for database connection
ssl_context = ssl.create_default_context()
ssl_context.check_hostname = False
ssl_context.verify_mode = ssl.CERT_REQUIRED

engine = create_async_engine(
    settings.database_url,
    echo=settings.log_level == "DEBUG",
    connect_args={
        "ssl": ssl_context,
        "server_settings": {
            "application_name": "solidity-security-api"
        }
    },
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True  # Verify connections before use
)
```

**Deliverables:**
- [ ] PostgreSQL TLS certificates generated
- [ ] PostgreSQL configured for TLS connections
- [ ] Database URL updated with sslmode=require
- [ ] SQLAlchemy SSL context configured
- [ ] Connection verification tests passing

**Estimated Time:** 6 hours
**Dependencies:** HashiCorp Vault setup
**Risk Level:** High (requires database downtime for TLS migration)

---

## Step 3: API Security (4 hours) 🟠 P1

### Objectives
- Implement comprehensive input validation
- Add rate limiting to all endpoints
- Configure strict CORS policy
- Add request/response logging

### 3.1 Input Validation

**Base Validators (`src/presentation/schemas/validators.py`):**
```python
import re
from pydantic import validator, Field, BaseModel

class EthereumAddressValidator:
    """Validator for Ethereum addresses"""
    @validator('contract_address')
    def validate_ethereum_address(cls, v):
        if not re.match(r'^0x[a-fA-F0-9]{40}$', v):
            raise ValueError('Invalid Ethereum address format')
        return v.lower()

class ContractAnalysisRequest(BaseModel, EthereumAddressValidator):
    contract_address: str = Field(
        ...,
        regex=r'^0x[a-fA-F0-9]{40}$',
        min_length=42,
        max_length=42,
        description="Ethereum contract address"
    )
    network: str = Field(
        ...,
        regex=r'^[a-z]+$',
        min_length=1,
        max_length=20,
        description="Blockchain network (mainnet, goerli, polygon, etc.)"
    )
    analysis_depth: str = Field(
        default="standard",
        regex=r'^(quick|standard|deep)$',
        description="Analysis depth level"
    )

# Sanitize text inputs
from bleach import clean

class CommentCreate(BaseModel):
    content: str = Field(..., min_length=1, max_length=1000)

    @validator('content')
    def sanitize_content(cls, v):
        # Remove any HTML/JavaScript
        return clean(v, tags=[], strip=True)
```

**Apply to All Endpoints:**
```python
@router.post("/contracts/analyze")
async def analyze_contract(
    request: ContractAnalysisRequest,  # Automatic validation
    current_user: User = Depends(get_current_user)
):
    # Request is already validated by Pydantic
    result = await contract_analyzer.analyze(
        address=request.contract_address,
        network=request.network
    )
    return result
```

**Deliverables:**
- [ ] Ethereum address validator
- [ ] Network name validator
- [ ] Text input sanitization
- [ ] File upload validation (size, type limits)
- [ ] SQL injection prevention verified

---

### 3.2 API Rate Limiting

**Install slowapi:**
```bash
poetry add slowapi redis
```

**Rate Limiter Configuration (`src/main.py`):**
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware

# Create limiter instance
limiter = Limiter(
    key_func=get_remote_address,
    default_limits=["200/minute"],  # Global default
    storage_uri=settings.redis_url
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)
app.add_middleware(SlowAPIMiddleware)

# Apply to endpoints
@router.post("/auth/login")
@limiter.limit("5/minute")  # Max 5 login attempts per minute
async def login(request: Request, credentials: LoginRequest):
    pass

@router.post("/contracts/analyze")
@limiter.limit("10/minute")  # Max 10 analyses per minute
async def analyze_contract(request: Request, data: ContractAnalysisRequest):
    pass

@router.get("/scans")
@limiter.limit("100/minute")  # Higher limit for read operations
async def list_scans(request: Request):
    pass
```

**User-Based Rate Limiting:**
```python
from slowapi.util import get_remote_address

def get_user_id(request: Request) -> str:
    """Get user ID from JWT for rate limiting"""
    token = request.cookies.get("access_token")
    if token:
        try:
            payload = decode_token(token)
            return payload["user_id"]
        except:
            pass
    return get_remote_address(request)

limiter = Limiter(key_func=get_user_id)

# Different limits for authenticated users
@router.post("/contracts/analyze")
@limiter.limit("50/hour")  # Authenticated users get higher limits
async def analyze_contract(
    request: Request,
    data: ContractAnalysisRequest,
    current_user: User = Depends(get_current_user)
):
    pass
```

**Deliverables:**
- [ ] slowapi rate limiter installed
- [ ] Redis backend for distributed rate limiting
- [ ] Rate limits applied to all endpoints
- [ ] User-based rate limiting for authenticated users
- [ ] Rate limit headers in responses

---

### 3.3 CORS Configuration

**Strict CORS Policy (`src/main.py`):**
```python
from fastapi.middleware.cors import CORSMiddleware

# Production CORS configuration
if settings.environment == "production":
    allowed_origins = [
        "https://app.soliditysecurity.com",
        "https://dashboard.soliditysecurity.com"
    ]
else:
    # Development allows localhost
    allowed_origins = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://localhost:5173"
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,  # Required for HttpOnly cookies
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Content-Type", "Authorization"],
    expose_headers=["X-RateLimit-Limit", "X-RateLimit-Remaining"],
    max_age=3600,
)
```

**Deliverables:**
- [ ] CORS middleware configured
- [ ] Production origins whitelisted
- [ ] Credentials enabled for cookies
- [ ] Preflight caching configured

---

### 3.4 Request/Response Logging

**Logging Middleware (`src/infrastructure/logging/middleware.py`):**
```python
import time
import logging
from fastapi import Request
import json

logger = logging.getLogger(__name__)

@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all API requests with security context"""
    request_id = str(uuid.uuid4())
    start_time = time.time()

    # Extract user context
    user_id = None
    try:
        token = request.cookies.get("access_token")
        if token:
            payload = decode_token(token)
            user_id = payload.get("user_id")
    except:
        pass

    # Log request
    logger.info(
        "Request started",
        extra={
            "request_id": request_id,
            "method": request.method,
            "path": request.url.path,
            "user_id": user_id,
            "ip_address": request.client.host,
            "user_agent": request.headers.get("user-agent"),
        }
    )

    # Process request
    response = await call_next(request)

    # Calculate duration
    duration = time.time() - start_time

    # Log response
    logger.info(
        "Request completed",
        extra={
            "request_id": request_id,
            "status_code": response.status_code,
            "duration_ms": round(duration * 1000, 2),
            "user_id": user_id,
        }
    )

    # Add request ID to response headers
    response.headers["X-Request-ID"] = request_id

    return response
```

**Structured Logging (`src/infrastructure/logging/config.py`):**
```python
import logging.config
import json
from pythonjsonlogger import jsonlogger

LOGGING_CONFIG = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {
            "()": "pythonjsonlogger.jsonlogger.JsonFormatter",
            "format": "%(asctime)s %(name)s %(levelname)s %(message)s",
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "json",
            "stream": "ext://sys.stdout",
        },
        "file": {
            "class": "logging.handlers.RotatingFileHandler",
            "formatter": "json",
            "filename": "/var/log/api-service/app.log",
            "maxBytes": 10485760,  # 10MB
            "backupCount": 5,
        }
    },
    "root": {
        "level": "INFO",
        "handlers": ["console", "file"]
    }
}

logging.config.dictConfig(LOGGING_CONFIG)
```

**Deliverables:**
- [ ] Request logging middleware
- [ ] Structured JSON logging
- [ ] User context in logs
- [ ] Request ID tracking
- [ ] Log aggregation (Loki integration)

**Estimated Time:** 4 hours
**Dependencies:** Redis for rate limiting
**Risk Level:** Low

---

## Step 4: Redis Security (2 hours) 🟡 P2

### Objectives
- Enable Redis authentication
- Configure TLS encryption
- Disable dangerous commands
- Implement connection pooling

**Redis Configuration (`k8s/base/redis/values-override.yaml`):**
```yaml
auth:
  enabled: true
  existingSecret: redis-secret
  existingSecretPasswordKey: redis-password

tls:
  enabled: true
  authClients: true
  certificatesSecret: redis-tls-cert
  certFilename: tls.crt
  certKeyFilename: tls.key
  certCAFilename: ca.crt

# Disable dangerous commands
disableCommands:
  - FLUSHDB
  - FLUSHALL
  - CONFIG
  - SHUTDOWN
  - BGREWRITEAOF
  - BGSAVE
  - SAVE

# Security settings
securityContext:
  enabled: true
  runAsUser: 1001
  fsGroup: 1001

# Network policies
networkPolicy:
  enabled: true
  allowExternal: false
```

**Update Redis Connection (`src/infrastructure/cache/redis.py`):**
```python
import redis.asyncio as redis
import ssl

ssl_context = ssl.create_default_context()

redis_client = redis.Redis(
    host=settings.redis_host,
    port=settings.redis_port,
    password=settings.redis_password,
    ssl=True,
    ssl_cert_reqs="required",
    ssl_context=ssl_context,
    decode_responses=True,
    max_connections=50,
    socket_keepalive=True,
    socket_connect_timeout=5,
    retry_on_timeout=True
)
```

**Deliverables:**
- [ ] Redis authentication enabled
- [ ] Redis TLS configured
- [ ] Dangerous commands disabled
- [ ] Connection pooling configured

**Estimated Time:** 2 hours
**Dependencies:** None
**Risk Level:** Medium

---

## Step 5: Operational Security (4 hours) 🟡 P2

### Objectives
- Implement automated database backups
- Create incident response playbook
- Configure security monitoring alerts
- Set up audit logging

### 5.1 Database Backups

**Backup CronJob (`k8s/base/postgresql/backup-cronjob.yaml`):**
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-backup
  namespace: postgresql-prod
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM UTC
  successfulJobsHistoryLimit: 7
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: backup
            image: postgres:15
            env:
            - name: PGHOST
              value: postgresql.postgresql-prod.svc.cluster.local
            - name: PGUSER
              value: postgres
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-secret
                  key: postgres-password
            - name: PGDATABASE
              value: solidity_security
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: backup-s3-credentials
                  key: access-key-id
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: backup-s3-credentials
                  key: secret-access-key
            command:
            - /bin/bash
            - -c
            - |
              TIMESTAMP=$(date +%Y%m%d-%H%M%S)
              BACKUP_FILE="/tmp/backup-${TIMESTAMP}.sql.gz"

              echo "Creating backup: ${BACKUP_FILE}"
              pg_dump | gzip > ${BACKUP_FILE}

              echo "Uploading to S3..."
              aws s3 cp ${BACKUP_FILE} \
                s3://soliditysecurity-backups/postgresql/daily/${BACKUP_FILE} \
                --storage-class STANDARD_IA

              echo "Backup completed successfully"
              rm ${BACKUP_FILE}
            volumeMounts:
            - name: backup-tmp
              mountPath: /tmp
          volumes:
          - name: backup-tmp
            emptyDir: {}
```

**Backup Retention Policy:**
```bash
# S3 lifecycle policy (apply via AWS console or Terraform)
{
  "Rules": [
    {
      "Id": "DailyBackupRetention",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
```

**Deliverables:**
- [ ] Daily backup CronJob deployed
- [ ] S3 backup storage configured
- [ ] Backup encryption enabled
- [ ] Retention policy applied
- [ ] Backup restore testing procedure

---

### 5.2 Incident Response Playbook

**Create (`docs/security/incident-response-playbook.md`):**
```markdown
# Security Incident Response Playbook

## 1. Detection & Triage (0-15 minutes)

### Alert Sources
- Prometheus/AlertManager alerts
- WAF blocking events
- Abnormal API rate limit triggers
- Failed authentication spike
- Database query anomalies

### Severity Classification
- **P0 - Critical**: Active data breach, complete service outage
- **P1 - High**: Suspected breach, partial service degradation
- **P2 - Medium**: Security policy violation, minor service impact
- **P3 - Low**: Security concern requiring investigation

### Initial Response
1. Acknowledge alert in incident channel
2. Assign incident commander
3. Create incident tracking ticket
4. Begin timeline documentation

## 2. Containment (15-60 minutes)

### Active Breach Response
- [ ] Revoke all user sessions: `kubectl exec -it api-service -- python -c "from src.infrastructure.database import revoke_all_sessions; revoke_all_sessions()"`
- [ ] Enable IP blocking at WAF level
- [ ] Rotate all API secrets in Vault
- [ ] Scale down affected services if needed
- [ ] Capture forensic data (logs, traffic dumps)

### Data Breach Response
- [ ] Identify scope of exposed data
- [ ] Preserve evidence (database snapshots, logs)
- [ ] Notify legal/compliance team
- [ ] Prepare breach notification (GDPR: 72 hours)

## 3. Investigation (1-4 hours)

### Data Collection
- Query Loki logs for suspicious patterns
- Review Prometheus metrics for anomalies
- Analyze database audit logs
- Check network flow logs

### Root Cause Analysis
- Identify vulnerability exploited
- Determine attack vector
- Assess damage/impact
- Document findings

## 4. Recovery (2-8 hours)

### Service Restoration
- [ ] Apply security patches
- [ ] Redeploy affected services
- [ ] Verify health checks passing
- [ ] Restore from backup if needed
- [ ] Gradually restore traffic

### Security Hardening
- [ ] Implement additional controls
- [ ] Update WAF rules
- [ ] Tighten network policies

## 5. Post-Incident (1-2 days)

### Documentation
- [ ] Complete incident report
- [ ] Timeline of events
- [ ] Root cause analysis
- [ ] Lessons learned
- [ ] Action items

### Communication
- [ ] User notification (if applicable)
- [ ] Regulatory notification (GDPR, etc.)
- [ ] Stakeholder briefing

### Follow-up
- [ ] Implement preventive measures
- [ ] Update runbooks
- [ ] Security training updates

## Emergency Contacts

- **Incident Commander**: [Name] - [Phone]
- **Security Lead**: [Name] - [Phone]
- **Platform Lead**: [Name] - [Phone]
- **Legal Counsel**: [Firm] - [Phone]
```

**Deliverables:**
- [ ] Incident response playbook created
- [ ] On-call rotation established
- [ ] Emergency contact list maintained
- [ ] Quarterly tabletop exercises

---

### 5.3 Security Monitoring

**AlertManager Rules (`k8s/base/monitoring/security-alerts.yaml`):**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: security-prometheus-rules
  namespace: monitoring-prod
data:
  security-alerts.yaml: |
    groups:
    - name: security
      interval: 30s
      rules:

      # Failed authentication spike
      - alert: HighAuthenticationFailureRate
        expr: |
          rate(api_auth_failed_total[5m]) > 10
        for: 2m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "High authentication failure rate detected"
          description: "{{ $value }} failed auth attempts per second"

      # Unusual API traffic
      - alert: APITrafficSpike
        expr: |
          rate(http_requests_total[5m]) > 1000
        for: 5m
        labels:
          severity: warning
          category: security
        annotations:
          summary: "Unusual API traffic spike"
          description: "{{ $value }} requests per second"

      # Vault secret access
      - alert: VaultSecretAccess
        expr: |
          increase(vault_secret_access_total[1h]) > 100
        labels:
          severity: info
          category: security
        annotations:
          summary: "High volume of Vault secret access"

      # Database connection failures
      - alert: DatabaseConnectionFailures
        expr: |
          rate(database_connection_errors_total[5m]) > 1
        for: 2m
        labels:
          severity: critical
          category: security
        annotations:
          summary: "Database connection failures detected"
```

**Deliverables:**
- [ ] Security alerts configured
- [ ] Slack/PagerDuty integration
- [ ] Grafana security dashboard
- [ ] Weekly security report automation

**Estimated Time:** 4 hours
**Dependencies:** Prometheus/Grafana setup
**Risk Level:** Low

---

## Step 6: Dependency Scanning & Container Security (3 hours) 🟡 P2

### Objectives
- Implement automated dependency scanning
- Configure container image scanning
- Generate Software Bill of Materials (SBOM)

**GitHub Actions Workflow (`.github/workflows/security-scan.yml`):**
```yaml
name: Security Scanning

on:
  push:
    branches: [main, develop]
  pull_request:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Run Snyk to check for vulnerabilities
      uses: snyk/actions/python@master
      env:
        SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
      with:
        args: --severity-threshold=high

    - name: Run Safety to check Python dependencies
      run: |
        pip install safety
        safety check --json

  container-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Build container image
      run: docker build -t api-service:${{ github.sha }} .

    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: api-service:${{ github.sha }}
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH'

    - name: Upload Trivy results to GitHub Security
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  sbom-generation:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Generate SBOM with Syft
      uses: anchore/sbom-action@v0
      with:
        path: .
        format: spdx-json
        output-file: sbom.spdx.json

    - name: Upload SBOM artifact
      uses: actions/upload-artifact@v3
      with:
        name: sbom
        path: sbom.spdx.json
```

**Pre-commit Hooks (`.pre-commit-config.yaml`):**
```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']

  - repo: https://github.com/pycqa/bandit
    rev: 1.7.5
    hooks:
      - id: bandit
        args: ['-r', 'src']
```

**Deliverables:**
- [ ] Snyk scanning configured
- [ ] Trivy container scanning
- [ ] SBOM generation automated
- [ ] Pre-commit secret detection
- [ ] Automated security PRs

**Estimated Time:** 3 hours
**Dependencies:** GitHub Actions, Snyk account
**Risk Level:** Low

---

## Testing & Validation Checklist

### Authentication Security
- [ ] HttpOnly cookies prevent JavaScript access
- [ ] Token refresh works with cookies
- [ ] HTTPS enforced in production
- [ ] Security headers present in responses
- [ ] HSTS header set correctly

### Infrastructure Security
- [ ] Secrets stored in Vault (not k8s secrets)
- [ ] Network policies block unauthorized traffic
- [ ] Pod security standards enforced
- [ ] Database connections use TLS
- [ ] Redis connections use TLS

### API Security
- [ ] Input validation prevents injection attacks
- [ ] Rate limiting enforced on all endpoints
- [ ] CORS policy allows only trusted origins
- [ ] Request logging captures security context
- [ ] Error messages don't leak sensitive info

### Operational Security
- [ ] Daily backups run successfully
- [ ] Backup restoration tested
- [ ] Security alerts trigger correctly
- [ ] Incident response playbook accessible
- [ ] Dependency scanning reports no critical issues

---

## Success Criteria

### Week 1 (P0 - Critical)
- [x] HttpOnly cookies implemented
- [x] Token rotation with reuse detection
- [x] HTTPS enforcement configured
- [x] Security headers middleware
- [x] Vault integration complete
- [x] Network policies deployed
- [x] Database TLS enabled

### Week 2 (P1 - High)
- [ ] Input validation on all endpoints
- [ ] API rate limiting operational
- [ ] CORS policy configured
- [ ] Request logging implemented
- [ ] WAF rules configured

### Week 3-4 (P2 - Medium)
- [ ] Redis security hardened
- [ ] Automated backups running
- [ ] Security monitoring alerts
- [ ] Incident response playbook
- [ ] Dependency scanning automated

---

## Timeline Summary

| Week | Focus Area | Tasks | Est. Hours |
|------|------------|-------|------------|
| 1 | Authentication & Secrets | HttpOnly cookies, token rotation, HTTPS, Vault | 16h |
| 1 | Infrastructure | Network policies, PSS, Database TLS | 14h |
| 2 | API Security | Validation, rate limiting, CORS, logging | 12h |
| 2 | WAF & Monitoring | WAF rules, security alerts | 8h |
| 3 | Data Security | Redis hardening, backups | 6h |
| 3 | Operations | Incident response, dependency scanning | 7h |
| 4 | Testing & Documentation | Security testing, documentation | 8h |

**Total Estimated Effort:** 71 hours (~2 weeks with 2 engineers)

---

## Dependencies & Prerequisites

### Required Before Starting
- HashiCorp Vault installed and configured
- Let's Encrypt certificate automation
- Prometheus/Grafana monitoring
- Snyk or similar scanning tool account
- S3 bucket for backups (or equivalent)

### Team Skills Required
- FastAPI middleware development
- Kubernetes NetworkPolicies
- HashiCorp Vault operations
- TLS/SSL certificate management
- Security testing tools (OWASP ZAP, Burp Suite)

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Auth breaking changes | Medium | High | Comprehensive testing, gradual rollout |
| Database TLS migration issues | Medium | Critical | Test in staging, maintenance window |
| Vault integration complexity | Low | High | Thorough documentation, fallback plan |
| Performance impact from logging | Low | Medium | Async logging, sampling in production |
| Rate limiting false positives | Medium | Medium | Generous initial limits, monitoring |

---

## Documentation Updates Required

- [ ] Update `docs/security/authentication-security.md` with implementation details
- [ ] Create `docs/security/incident-response-playbook.md`
- [ ] Create `docs/security/production-security-checklist.md`
- [ ] Update `docs/deployment/production-deployment.md` with security requirements
- [ ] Update developer onboarding docs with security guidelines

---

## Post-Implementation Review

### Security Audit (Week 5)
- [ ] External penetration testing
- [ ] OWASP ZAP automated scan
- [ ] Manual security testing
- [ ] Code review for security issues
- [ ] Compliance assessment (GDPR, SOC 2)

### Performance Testing
- [ ] Load testing with security controls
- [ ] Rate limiting behavior under load
- [ ] Logging performance impact
- [ ] Database connection pooling optimization

---

**Task Owner:** Security Team
**Estimated Duration:** 2-4 weeks
**Priority:** 🔴 Critical for Production
**Status:** ⏳ Pending

**Related Tasks:**
- Task 1.17: Final Platform Validation
- Sprint 14: Authentication & Authorization (from sprint-plan_new.md)

**Related Documentation:**
- `docs/security/authentication-security.md`
- `docs/Sprints/Sprint-1/API-Service-Deployment-COMPLETION.md`
