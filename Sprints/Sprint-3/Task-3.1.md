# Task 3.1: FastAPI Application with DDD Architecture

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 8 hours
**Owner**: Backend Team
**Priority**: P0 (Critical)
**Repository**: `solidity-security-api-service`

## Overview

Implement a comprehensive FastAPI application using Domain-Driven Design (DDD), Clean Architecture, and CQRS patterns. This service will serve as the primary API gateway for the Solidity Security Platform, handling authentication, user management, and project orchestration.

## Technical Requirements

### Architecture Pattern
- **Domain-Driven Design (DDD)**: Pure business logic separation
- **Clean Architecture**: 4-layer architectural pattern
- **CQRS**: Command Query Responsibility Segregation
- **Repository Pattern**: Data access abstraction

### Technology Stack
```yaml
Framework: FastAPI 0.104+
Python: Python 3.13 (latest with performance improvements)
Validation: Pydantic V2 (enhanced performance)
Database: SQLAlchemy 2.0+ with async support
Authentication: JWT with refresh token rotation
Documentation: OpenAPI 3.0 with Swagger UI
Monitoring: Prometheus metrics integration
Caching: Redis integration for session management
```

### Development Standards
- **Type Hints**: Comprehensive type annotations using Python 3.13 features
- **Async/Await**: Full async implementation for I/O operations
- **Error Handling**: Structured exception handling with proper HTTP status codes
- **Logging**: Structured logging with correlation IDs
- **Testing**: 90%+ code coverage with pytest

## Domain-Driven Design Implementation

### 1. Domain Layer (Pure Business Logic)

**Entities**:
```python
# domain/entities/user.py
from dataclasses import dataclass
from typing import List, Optional
from datetime import datetime
from .base import BaseEntity
from ..value_objects import Email, UserId

@dataclass
class User(BaseEntity):
    user_id: UserId
    email: Email
    username: str
    roles: List[str]
    is_active: bool
    created_at: datetime
    updated_at: datetime

    def has_role(self, role: str) -> bool:
        return role in self.roles

    def can_access_project(self, project: 'Project') -> bool:
        return self.user_id == project.owner_id or 'admin' in self.roles
```

**Value Objects**:
```python
# domain/value_objects/email.py
from dataclasses import dataclass
import re

@dataclass(frozen=True)
class Email:
    value: str

    def __post_init__(self):
        if not self._is_valid_email(self.value):
            raise ValueError(f"Invalid email format: {self.value}")

    def _is_valid_email(self, email: str) -> bool:
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))
```

**Domain Services**:
```python
# domain/services/auth_service.py
from typing import Optional
from ..entities import User
from ..value_objects import Email, Password

class AuthenticationService:
    def authenticate_user(self, email: Email, password: Password) -> Optional[User]:
        # Domain logic for user authentication
        pass

    def generate_access_token(self, user: User) -> str:
        # Domain logic for token generation
        pass

    def validate_token(self, token: str) -> Optional[User]:
        # Domain logic for token validation
        pass
```

### 2. Application Layer (Use Cases with CQRS)

**Commands** (Write Operations):
```python
# application/auth/commands/login_command.py
from dataclasses import dataclass
from typing import Optional
from ...domain.value_objects import Email, Password

@dataclass
class LoginCommand:
    email: str
    password: str

    def to_domain(self) -> tuple[Email, Password]:
        return Email(self.email), Password(self.password)

# application/auth/handlers/auth_command_handlers.py
class AuthCommandHandlers:
    def __init__(self, auth_service: AuthenticationService, user_repo: UserRepository):
        self.auth_service = auth_service
        self.user_repo = user_repo

    async def handle_login(self, command: LoginCommand) -> LoginResult:
        email, password = command.to_domain()
        user = await self.auth_service.authenticate_user(email, password)
        if user:
            token = self.auth_service.generate_access_token(user)
            return LoginResult(success=True, token=token, user=user)
        return LoginResult(success=False, error="Invalid credentials")
```

**Queries** (Read Operations):
```python
# application/users/queries/get_user_query.py
@dataclass
class GetUserQuery:
    user_id: str

# application/users/handlers/user_query_handlers.py
class UserQueryHandlers:
    def __init__(self, user_repo: UserRepository):
        self.user_repo = user_repo

    async def handle_get_user(self, query: GetUserQuery) -> Optional[User]:
        return await self.user_repo.get_by_id(UserId(query.user_id))
```

### 3. Infrastructure Layer (External Concerns)

**Repository Implementations**:
```python
# infrastructure/database/repositories/user_repository_impl.py
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from ...domain.repositories import UserRepository
from ...domain.entities import User
from ...domain.value_objects import UserId, Email

class SqlAlchemyUserRepository(UserRepository):
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_id(self, user_id: UserId) -> Optional[User]:
        # SQLAlchemy implementation
        pass

    async def get_by_email(self, email: Email) -> Optional[User]:
        # SQLAlchemy implementation
        pass

    async def save(self, user: User) -> User:
        # SQLAlchemy implementation
        pass
```

**Database Models**:
```python
# infrastructure/database/models/user_model.py
from sqlalchemy import Column, String, Boolean, DateTime, JSON
from sqlalchemy.dialects.postgresql import UUID
from .base_model import BaseModel

class UserModel(BaseModel):
    __tablename__ = "users"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    roles = Column(JSON, default=list)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
```

### 4. Presentation Layer (FastAPI Interface)

**API Endpoints**:
```python
# presentation/api/v1/auth/router.py
from fastapi import APIRouter, Depends, HTTPException
from ....application.auth.commands import LoginCommand
from ....application.auth.handlers import AuthCommandHandlers
from .schemas import LoginRequest, LoginResponse

router = APIRouter(prefix="/auth", tags=["authentication"])

@router.post("/login", response_model=LoginResponse)
async def login(
    request: LoginRequest,
    auth_handler: AuthCommandHandlers = Depends(get_auth_handler)
) -> LoginResponse:
    command = LoginCommand(email=request.email, password=request.password)
    result = await auth_handler.handle_login(command)

    if result.success:
        return LoginResponse(
            access_token=result.token,
            token_type="bearer",
            user=UserSchema.from_entity(result.user)
        )

    raise HTTPException(status_code=401, detail=result.error)
```

**Request/Response Schemas**:
```python
# presentation/api/v1/auth/schemas.py
from pydantic import BaseModel, EmailStr
from typing import List, Optional

class LoginRequest(BaseModel):
    email: EmailStr
    password: str

class UserSchema(BaseModel):
    id: str
    email: str
    username: str
    roles: List[str]
    is_active: bool

    @classmethod
    def from_entity(cls, user: User) -> "UserSchema":
        return cls(
            id=str(user.user_id.value),
            email=user.email.value,
            username=user.username,
            roles=user.roles,
            is_active=user.is_active
        )

class LoginResponse(BaseModel):
    access_token: str
    token_type: str
    expires_in: int = 3600
    user: UserSchema
```

## Authentication Implementation

### JWT Token System
```python
# infrastructure/security/jwt_handler.py
from datetime import datetime, timedelta
from typing import Optional
import jwt
from ...domain.entities import User

class JWTHandler:
    def __init__(self, secret_key: str, algorithm: str = "HS256"):
        self.secret_key = secret_key
        self.algorithm = algorithm
        self.access_token_expire = timedelta(hours=1)
        self.refresh_token_expire = timedelta(days=7)

    def create_access_token(self, user: User) -> str:
        expire = datetime.utcnow() + self.access_token_expire
        payload = {
            "sub": str(user.user_id.value),
            "email": user.email.value,
            "roles": user.roles,
            "exp": expire,
            "type": "access"
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)

    def create_refresh_token(self, user: User) -> str:
        expire = datetime.utcnow() + self.refresh_token_expire
        payload = {
            "sub": str(user.user_id.value),
            "exp": expire,
            "type": "refresh"
        }
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)

    def verify_token(self, token: str) -> Optional[dict]:
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
```

### OAuth 2.0 Integration Framework
```python
# infrastructure/security/oauth_providers.py
from abc import ABC, abstractmethod
from typing import Optional, Dict, Any
import httpx

class OAuthProvider(ABC):
    @abstractmethod
    async def get_user_info(self, access_token: str) -> Optional[Dict[str, Any]]:
        pass

class GoogleOAuthProvider(OAuthProvider):
    def __init__(self, client_id: str, client_secret: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.userinfo_endpoint = "https://www.googleapis.com/oauth2/v2/userinfo"

    async def get_user_info(self, access_token: str) -> Optional[Dict[str, Any]]:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                self.userinfo_endpoint,
                headers={"Authorization": f"Bearer {access_token}"}
            )
            if response.status_code == 200:
                return response.json()
            return None
```

## API Versioning Strategy

### Version Management
```python
# presentation/api/versioning.py
from fastapi import FastAPI, APIRouter
from .v1 import auth_router as auth_v1, users_router as users_v1
from .v2 import auth_router as auth_v2  # Future version

def setup_api_versioning(app: FastAPI):
    # Version 1 (current)
    v1_router = APIRouter(prefix="/api/v1")
    v1_router.include_router(auth_v1)
    v1_router.include_router(users_v1)
    app.include_router(v1_router)

    # Version 2 (future)
    # v2_router = APIRouter(prefix="/api/v2")
    # v2_router.include_router(auth_v2)
    # app.include_router(v2_router)

    # Default to latest version
    app.include_router(v1_router, prefix="/api")
```

## Health Checks and Monitoring

### Health Check Implementation
```python
# presentation/api/health/router.py
from fastapi import APIRouter, Depends, HTTPException
from ....infrastructure.database import get_db_session
from ....infrastructure.monitoring import HealthChecker

router = APIRouter(prefix="/health", tags=["health"])

@router.get("/")
async def health_check():
    return {"status": "healthy", "timestamp": datetime.utcnow().isoformat()}

@router.get("/detailed")
async def detailed_health_check(
    health_checker: HealthChecker = Depends(get_health_checker)
):
    checks = await health_checker.run_all_checks()
    overall_status = "healthy" if all(check["healthy"] for check in checks.values()) else "unhealthy"

    return {
        "status": overall_status,
        "timestamp": datetime.utcnow().isoformat(),
        "checks": checks
    }

# infrastructure/monitoring/health_checker.py
class HealthChecker:
    def __init__(self, db_session, redis_client, vault_client):
        self.db_session = db_session
        self.redis_client = redis_client
        self.vault_client = vault_client

    async def run_all_checks(self) -> Dict[str, Dict[str, Any]]:
        return {
            "database": await self.check_database(),
            "redis": await self.check_redis(),
            "vault": await self.check_vault(),
        }

    async def check_database(self) -> Dict[str, Any]:
        try:
            await self.db_session.execute(text("SELECT 1"))
            return {"healthy": True, "response_time_ms": 0}
        except Exception as e:
            return {"healthy": False, "error": str(e)}
```

### Prometheus Metrics
```python
# infrastructure/monitoring/metrics.py
from prometheus_client import Counter, Histogram, Gauge
import time
from functools import wraps

# Metrics definitions
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')
ACTIVE_USERS = Gauge('active_users_total', 'Number of active users')
DATABASE_CONNECTIONS = Gauge('database_connections_active', 'Active database connections')

def track_request_metrics(func):
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = await func(*args, **kwargs)
            REQUEST_COUNT.labels(method="POST", endpoint="/api/v1/auth/login", status="200").inc()
            return result
        except Exception as e:
            REQUEST_COUNT.labels(method="POST", endpoint="/api/v1/auth/login", status="500").inc()
            raise
        finally:
            REQUEST_DURATION.observe(time.time() - start_time)
    return wrapper
```

## Configuration Management

### Environment Configuration
```python
# shared/config/settings.py
from pydantic import BaseSettings, PostgresDsn, RedisDsn
from typing import List, Optional

class Settings(BaseSettings):
    # Application
    app_name: str = "Solidity Security API"
    debug: bool = False
    api_version: str = "v1"

    # Database
    database_url: PostgresDsn
    database_echo: bool = False
    database_pool_size: int = 20
    database_max_overflow: int = 30

    # Redis
    redis_url: RedisDsn
    redis_max_connections: int = 50

    # JWT
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 60
    jwt_refresh_token_expire_days: int = 7

    # OAuth
    google_client_id: Optional[str] = None
    google_client_secret: Optional[str] = None
    github_client_id: Optional[str] = None
    github_client_secret: Optional[str] = None

    # CORS
    cors_origins: List[str] = ["http://localhost:3000"]
    cors_allow_credentials: bool = True

    # Monitoring
    enable_metrics: bool = True
    log_level: str = "INFO"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

## Testing Strategy

### Unit Tests
```python
# tests/unit/domain/test_user_entity.py
import pytest
from src.domain.entities import User
from src.domain.value_objects import Email, UserId

class TestUserEntity:
    def test_user_has_role_returns_true_when_role_exists(self):
        user = User(
            user_id=UserId("123"),
            email=Email("test@example.com"),
            username="testuser",
            roles=["admin", "user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        assert user.has_role("admin") is True
        assert user.has_role("moderator") is False
```

### Integration Tests
```python
# tests/integration/test_auth_endpoints.py
import pytest
from fastapi.testclient import TestClient
from httpx import AsyncClient

@pytest.mark.asyncio
class TestAuthEndpoints:
    async def test_login_success(self, async_client: AsyncClient, test_user):
        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": test_user.email, "password": "testpassword"}
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == test_user.email
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Code Structure
```
src/
├── domain/                     # Domain Layer
│   ├── entities/              # Business entities
│   ├── repositories/          # Repository interfaces
│   ├── services/              # Domain services
│   ├── value_objects/         # Value objects
│   └── exceptions/            # Domain exceptions
├── application/               # Application Layer
│   ├── auth/                  # Authentication use cases
│   ├── users/                 # User management use cases
│   ├── projects/              # Project management use cases
│   └── analysis/              # Analysis workflow use cases
├── infrastructure/            # Infrastructure Layer
│   ├── database/              # Database implementations
│   ├── external_services/     # External service clients
│   ├── monitoring/            # Monitoring implementations
│   ├── security/              # Security implementations
│   └── messaging/             # Message queue implementations
├── presentation/              # Presentation Layer
│   ├── api/                   # FastAPI endpoints
│   ├── middleware/            # Custom middleware
│   └── exception_handlers.py  # Global exception handling
├── shared/                    # Shared utilities
│   ├── config/                # Configuration management
│   ├── constants/             # Application constants
│   ├── utils/                 # Utility functions
│   └── events/                # Domain events
└── main.py                    # Application entry point
```

### Features Implemented
- ✅ Domain-Driven Design with 4-layer architecture
- ✅ CQRS pattern for command/query separation
- ✅ JWT authentication with refresh token rotation
- ✅ OAuth 2.0 integration framework
- ✅ Comprehensive user management system
- ✅ Role-based access control (RBAC)
- ✅ API versioning strategy
- ✅ Health check endpoints with dependency validation
- ✅ Prometheus metrics integration
- ✅ Structured logging with correlation IDs
- ✅ Comprehensive test suite with 90%+ coverage

## Acceptance Criteria

### Architecture Validation
- [ ] DDD architecture properly implemented with clear layer boundaries
- [ ] CQRS pattern separates commands and queries effectively
- [ ] Repository pattern abstracts data access successfully
- [ ] Domain logic isolated from infrastructure concerns

### Authentication Security
- [ ] JWT tokens properly signed and validated
- [ ] Refresh token rotation working correctly
- [ ] OAuth 2.0 integration functional for major providers
- [ ] RBAC enforced across all protected endpoints

### API Functionality
- [ ] All endpoints follow RESTful conventions
- [ ] OpenAPI documentation auto-generated and accessible
- [ ] API versioning strategy supports backward compatibility
- [ ] Error responses follow consistent format

### Performance & Monitoring
- [ ] Health checks validate all service dependencies
- [ ] Prometheus metrics available for all endpoints
- [ ] Structured logging provides proper correlation
- [ ] Response times under 100ms for 95th percentile

### Quality Assurance
- [ ] Unit tests achieve 90%+ code coverage
- [ ] Integration tests validate complete workflows
- [ ] Security tests verify authentication and authorization
- [ ] Performance tests establish baseline metrics

This task establishes the foundation for all subsequent backend development, providing a scalable, secure, and well-architected API service using modern Python development standards.