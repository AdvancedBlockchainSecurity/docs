# Task 3.5: Inter-Service Communication

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 6 hours
**Owner**: Backend Team
**Priority**: P0 (Critical)
**Repository**: Multiple (`api-service`, `data-service`, `notification`)

## Overview

Implement secure and reliable inter-service communication patterns for the backend microservices. This includes HTTP REST APIs, authentication propagation, circuit breaker patterns, and distributed tracing to ensure robust service-to-service communication.

## Technical Requirements

### Communication Standards
```yaml
Protocol: HTTP/1.1 with keep-alive connections
Authentication: JWT bearer tokens with service-to-service validation
Resilience: Circuit breaker with exponential backoff
Discovery: Kubernetes ClusterIP services with DNS resolution
Monitoring: Distributed tracing with correlation IDs
Error Handling: Standardized error response format
Load Balancing: Kubernetes service load balancing
Timeout Management: Configurable request timeouts
Retry Logic: Exponential backoff with jitter
```

### Performance Targets
- **Service Communication**: Sub-50ms response times within cluster
- **Authentication**: JWT validation under 10ms
- **Circuit Breaker**: Sub-1ms decision time
- **Connection Pooling**: Efficient resource utilization
- **Error Recovery**: Automatic retry with intelligent backoff

## Service Communication Architecture

### Service Communication Matrix
```yaml
API Service Communications:
  → Data Service: User authentication, project management, CRUD operations
  → Notification Service: Real-time updates, system alerts, user notifications
  → Intelligence Engine: Future integration for analysis results
  → Tool Integration: Future integration for security tool management

Data Service Communications:
  → Notification Service: Database event notifications, audit alerts
  → Cache Service: Redis operations for performance optimization
  → External APIs: Future integrations for data enrichment

Notification Service Communications:
  → Data Service: User preference lookups, audit logging
  → External Services: Email, Slack, webhook integrations

All Services:
  → Monitoring Service: Metrics, logs, health status reporting
  → Vault Service: Secret retrieval and validation
```

### HTTP Client Implementation

#### Base HTTP Client with Circuit Breaker
```python
# shared/http_client/base_client.py
import asyncio
import httpx
from typing import Optional, Dict, Any, Union
from datetime import datetime, timedelta
import logging
from enum import Enum
from dataclasses import dataclass, field
import json

logger = logging.getLogger(__name__)

class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"

@dataclass
class CircuitBreakerConfig:
    failure_threshold: int = 5
    recovery_timeout: int = 60
    expected_exception: type = httpx.RequestError
    name: str = "default"

@dataclass
class CircuitBreakerStats:
    state: CircuitState = CircuitState.CLOSED
    failure_count: int = 0
    last_failure_time: Optional[datetime] = None
    success_count: int = 0
    total_requests: int = 0

class CircuitBreaker:
    def __init__(self, config: CircuitBreakerConfig):
        self.config = config
        self.stats = CircuitBreakerStats()
        self._lock = asyncio.Lock()

    async def call(self, func, *args, **kwargs):
        async with self._lock:
            if self.stats.state == CircuitState.OPEN:
                if self._should_attempt_reset():
                    self.stats.state = CircuitState.HALF_OPEN
                    logger.info(f"Circuit breaker {self.config.name} transitioning to HALF_OPEN")
                else:
                    raise Exception(f"Circuit breaker {self.config.name} is OPEN")

        try:
            result = await func(*args, **kwargs)
            await self._on_success()
            return result
        except self.config.expected_exception as e:
            await self._on_failure()
            raise
        except Exception as e:
            # Don't count non-expected exceptions as failures
            logger.error(f"Unexpected error in circuit breaker {self.config.name}: {e}")
            raise

    def _should_attempt_reset(self) -> bool:
        if self.stats.last_failure_time is None:
            return True
        return datetime.utcnow() - self.stats.last_failure_time > timedelta(seconds=self.config.recovery_timeout)

    async def _on_success(self):
        async with self._lock:
            self.stats.success_count += 1
            self.stats.total_requests += 1

            if self.stats.state == CircuitState.HALF_OPEN:
                self.stats.state = CircuitState.CLOSED
                self.stats.failure_count = 0
                logger.info(f"Circuit breaker {self.config.name} reset to CLOSED")

    async def _on_failure(self):
        async with self._lock:
            self.stats.failure_count += 1
            self.stats.total_requests += 1
            self.stats.last_failure_time = datetime.utcnow()

            if self.stats.failure_count >= self.config.failure_threshold:
                self.stats.state = CircuitState.OPEN
                logger.warning(f"Circuit breaker {self.config.name} tripped to OPEN")

class BaseHTTPClient:
    def __init__(
        self,
        base_url: str,
        timeout: float = 30.0,
        retries: int = 3,
        circuit_breaker_config: Optional[CircuitBreakerConfig] = None
    ):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.retries = retries

        # HTTP client configuration
        self.client = httpx.AsyncClient(
            timeout=httpx.Timeout(timeout),
            limits=httpx.Limits(
                max_keepalive_connections=20,
                max_connections=100,
                keepalive_expiry=30.0
            ),
            headers={
                "User-Agent": "Solidity-Security-Platform/1.0",
                "Accept": "application/json",
                "Content-Type": "application/json"
            }
        )

        # Circuit breaker setup
        if circuit_breaker_config:
            self.circuit_breaker = CircuitBreaker(circuit_breaker_config)
        else:
            self.circuit_breaker = CircuitBreaker(CircuitBreakerConfig(name=base_url))

    async def request(
        self,
        method: str,
        path: str,
        headers: Optional[Dict[str, str]] = None,
        params: Optional[Dict[str, Any]] = None,
        json_data: Optional[Dict[str, Any]] = None,
        auth_token: Optional[str] = None,
        correlation_id: Optional[str] = None
    ) -> httpx.Response:
        """Make HTTP request with circuit breaker protection"""
        url = f"{self.base_url}{path}"

        # Prepare headers
        request_headers = {}
        if headers:
            request_headers.update(headers)

        if auth_token:
            request_headers["Authorization"] = f"Bearer {auth_token}"

        if correlation_id:
            request_headers["X-Correlation-ID"] = correlation_id

        # Make request with circuit breaker protection
        return await self.circuit_breaker.call(
            self._make_request_with_retry,
            method, url, request_headers, params, json_data
        )

    async def _make_request_with_retry(
        self,
        method: str,
        url: str,
        headers: Dict[str, str],
        params: Optional[Dict[str, Any]],
        json_data: Optional[Dict[str, Any]]
    ) -> httpx.Response:
        """Make HTTP request with exponential backoff retry"""
        last_exception = None

        for attempt in range(self.retries + 1):
            try:
                response = await self.client.request(
                    method=method,
                    url=url,
                    headers=headers,
                    params=params,
                    json=json_data
                )

                # Log successful request
                logger.debug(f"{method} {url} -> {response.status_code} (attempt {attempt + 1})")

                if response.status_code < 500:  # Don't retry on client errors
                    return response

                if attempt == self.retries:  # Last attempt
                    return response

            except httpx.RequestError as e:
                last_exception = e
                logger.warning(f"{method} {url} failed (attempt {attempt + 1}): {e}")

                if attempt == self.retries:  # Last attempt
                    break

            # Exponential backoff with jitter
            if attempt < self.retries:
                delay = (2 ** attempt) + (asyncio.get_event_loop().time() % 1)
                await asyncio.sleep(delay)

        # If we get here, all retries failed
        if last_exception:
            raise last_exception
        else:
            raise Exception(f"Request failed after {self.retries + 1} attempts")

    async def get(self, path: str, **kwargs) -> httpx.Response:
        return await self.request("GET", path, **kwargs)

    async def post(self, path: str, **kwargs) -> httpx.Response:
        return await self.request("POST", path, **kwargs)

    async def put(self, path: str, **kwargs) -> httpx.Response:
        return await self.request("PUT", path, **kwargs)

    async def delete(self, path: str, **kwargs) -> httpx.Response:
        return await self.request("DELETE", path, **kwargs)

    async def close(self):
        await self.client.aclose()

    def get_circuit_breaker_stats(self) -> Dict[str, Any]:
        stats = self.circuit_breaker.stats
        return {
            "state": stats.state.value,
            "failure_count": stats.failure_count,
            "success_count": stats.success_count,
            "total_requests": stats.total_requests,
            "last_failure_time": stats.last_failure_time.isoformat() if stats.last_failure_time else None
        }
```

#### Service-Specific HTTP Clients
```python
# api-service/src/infrastructure/external_services/data_service_client.py
from typing import List, Optional, Dict, Any
from ...shared.http_client.base_client import BaseHTTPClient, CircuitBreakerConfig
from ...domain.entities import User, Project, Analysis
import uuid

class DataServiceClient:
    def __init__(self, base_url: str):
        circuit_config = CircuitBreakerConfig(
            failure_threshold=3,
            recovery_timeout=30,
            name="data-service"
        )
        self.client = BaseHTTPClient(base_url, circuit_breaker_config=circuit_config)

    async def get_user_by_id(self, user_id: str, auth_token: str, correlation_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID from data service"""
        try:
            response = await self.client.get(
                f"/api/v1/users/{user_id}",
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            if response.status_code == 200:
                return response.json()
            elif response.status_code == 404:
                return None
            else:
                response.raise_for_status()

        except Exception as e:
            logger.error(f"Failed to get user {user_id}: {e}")
            raise

    async def create_project(
        self,
        project_data: Dict[str, Any],
        auth_token: str,
        correlation_id: str
    ) -> Dict[str, Any]:
        """Create new project in data service"""
        try:
            response = await self.client.post(
                "/api/v1/projects",
                json_data=project_data,
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            response.raise_for_status()
            return response.json()

        except Exception as e:
            logger.error(f"Failed to create project: {e}")
            raise

    async def get_user_projects(
        self,
        user_id: str,
        auth_token: str,
        correlation_id: str,
        skip: int = 0,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get projects for a user"""
        try:
            response = await self.client.get(
                f"/api/v1/users/{user_id}/projects",
                params={"skip": skip, "limit": limit},
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            response.raise_for_status()
            return response.json()

        except Exception as e:
            logger.error(f"Failed to get projects for user {user_id}: {e}")
            raise

    async def create_analysis(
        self,
        analysis_data: Dict[str, Any],
        auth_token: str,
        correlation_id: str
    ) -> Dict[str, Any]:
        """Create new analysis record"""
        try:
            response = await self.client.post(
                "/api/v1/analyses",
                json_data=analysis_data,
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            response.raise_for_status()
            return response.json()

        except Exception as e:
            logger.error(f"Failed to create analysis: {e}")
            raise

    async def update_analysis_status(
        self,
        analysis_id: str,
        status: str,
        metadata: Optional[Dict[str, Any]],
        auth_token: str,
        correlation_id: str
    ) -> Dict[str, Any]:
        """Update analysis status"""
        try:
            update_data = {"status": status}
            if metadata:
                update_data["execution_metadata"] = metadata

            response = await self.client.put(
                f"/api/v1/analyses/{analysis_id}",
                json_data=update_data,
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            response.raise_for_status()
            return response.json()

        except Exception as e:
            logger.error(f"Failed to update analysis {analysis_id}: {e}")
            raise

    async def health_check(self) -> bool:
        """Check if data service is healthy"""
        try:
            response = await self.client.get("/health")
            return response.status_code == 200
        except Exception:
            return False

    def get_stats(self) -> Dict[str, Any]:
        return self.client.get_circuit_breaker_stats()

    async def close(self):
        await self.client.close()

# api-service/src/infrastructure/external_services/notification_service_client.py
class NotificationServiceClient:
    def __init__(self, base_url: str):
        circuit_config = CircuitBreakerConfig(
            failure_threshold=5,
            recovery_timeout=60,
            name="notification-service"
        )
        self.client = BaseHTTPClient(base_url, circuit_breaker_config=circuit_config)

    async def send_notification(
        self,
        notification_data: Dict[str, Any],
        auth_token: str,
        correlation_id: str
    ) -> bool:
        """Send notification via notification service"""
        try:
            response = await self.client.post(
                "/api/v1/notify",
                json_data=notification_data,
                auth_token=auth_token,
                correlation_id=correlation_id
            )

            return response.status_code in [200, 202]

        except Exception as e:
            logger.error(f"Failed to send notification: {e}")
            return False

    async def send_analysis_started_notification(
        self,
        analysis_id: str,
        project_id: str,
        user_id: str,
        auth_token: str,
        correlation_id: str
    ) -> bool:
        """Send analysis started notification"""
        notification_data = {
            "type": "analysis:started",
            "data": {
                "analysisId": analysis_id,
                "projectId": project_id,
                "userId": user_id,
            },
            "projectId": project_id,
            "priority": 1
        }

        return await self.send_notification(notification_data, auth_token, correlation_id)

    async def send_analysis_completed_notification(
        self,
        analysis_id: str,
        project_id: str,
        status: str,
        results: Dict[str, Any],
        auth_token: str,
        correlation_id: str
    ) -> bool:
        """Send analysis completed notification"""
        notification_data = {
            "type": "analysis:completed",
            "data": {
                "analysisId": analysis_id,
                "projectId": project_id,
                "status": status,
                "results": results,
            },
            "projectId": project_id,
            "priority": 2
        }

        return await self.send_notification(notification_data, auth_token, correlation_id)

    async def health_check(self) -> bool:
        """Check if notification service is healthy"""
        try:
            response = await self.client.get("/health")
            return response.status_code == 200
        except Exception:
            return False

    def get_stats(self) -> Dict[str, Any]:
        return self.client.get_circuit_breaker_stats()

    async def close(self):
        await self.client.close()
```

## JWT Token Propagation

### Authentication Middleware for Inter-Service Calls
```python
# shared/middleware/service_auth.py
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
import jwt
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class ServiceAuthenticationManager:
    def __init__(self, jwt_secret: str, service_name: str):
        self.jwt_secret = jwt_secret
        self.service_name = service_name

    def extract_token_from_request(self, authorization_header: Optional[str]) -> Optional[str]:
        """Extract JWT token from Authorization header"""
        if not authorization_header:
            return None

        if not authorization_header.startswith("Bearer "):
            return None

        return authorization_header[7:]  # Remove "Bearer " prefix

    def validate_token(self, token: str) -> Dict[str, Any]:
        """Validate JWT token and return claims"""
        try:
            payload = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=["HS256"]
            )

            # Check token expiration
            exp = payload.get("exp")
            if exp and datetime.utcfromtimestamp(exp) < datetime.utcnow():
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Token has expired"
                )

            return payload

        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid JWT token: {e}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication token"
            )

    def create_service_token(self, user_claims: Dict[str, Any]) -> str:
        """Create a service-to-service token with extended validity"""
        now = datetime.utcnow()
        service_claims = {
            **user_claims,
            "iss": self.service_name,
            "iat": now,
            "exp": now + timedelta(minutes=10),  # Short-lived for service calls
            "service": True
        }

        return jwt.encode(service_claims, self.jwt_secret, algorithm="HS256")

    def propagate_authentication(self, original_token: str) -> str:
        """Propagate user authentication to service calls"""
        # Validate the original token
        claims = self.validate_token(original_token)

        # Create a new token for service-to-service communication
        return self.create_service_token(claims)

# Dependency for FastAPI
async def get_current_user_from_token(
    authorization: Optional[str] = Header(None),
    auth_manager: ServiceAuthenticationManager = Depends(get_auth_manager)
) -> Dict[str, Any]:
    """FastAPI dependency to extract and validate user from token"""
    token = auth_manager.extract_token_from_request(authorization)

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication token required"
        )

    return auth_manager.validate_token(token)
```

### Token Propagation in Service Calls
```python
# api-service/src/presentation/api/v1/projects/router.py
from fastapi import APIRouter, Depends, HTTPException, Header
from typing import Optional, List
from .....application.projects.commands import CreateProjectCommand
from .....application.projects.handlers import ProjectCommandHandlers
from .....infrastructure.external_services import DataServiceClient, NotificationServiceClient
from .....shared.middleware.service_auth import get_current_user_from_token, ServiceAuthenticationManager
from .....shared.utils.correlation import get_correlation_id
from .schemas import CreateProjectRequest, ProjectResponse

router = APIRouter(prefix="/projects", tags=["projects"])

@router.post("/", response_model=ProjectResponse)
async def create_project(
    request: CreateProjectRequest,
    current_user: Dict[str, Any] = Depends(get_current_user_from_token),
    authorization: Optional[str] = Header(None),
    correlation_id: str = Depends(get_correlation_id),
    data_service: DataServiceClient = Depends(get_data_service_client),
    notification_service: NotificationServiceClient = Depends(get_notification_service_client),
    auth_manager: ServiceAuthenticationManager = Depends(get_auth_manager)
) -> ProjectResponse:
    """Create a new project with inter-service communication"""
    try:
        # Extract original token for propagation
        original_token = auth_manager.extract_token_from_request(authorization)
        service_token = auth_manager.propagate_authentication(original_token)

        # Create project via data service
        project_data = {
            "name": request.name,
            "description": request.description,
            "owner_id": current_user["sub"],
            "settings": request.settings or {}
        }

        project = await data_service.create_project(
            project_data,
            auth_token=service_token,
            correlation_id=correlation_id
        )

        # Send notification
        await notification_service.send_notification(
            {
                "type": "project:created",
                "data": {
                    "projectId": project["id"],
                    "projectName": project["name"],
                    "ownerId": current_user["sub"]
                },
                "userId": current_user["sub"],
                "priority": 1
            },
            auth_token=service_token,
            correlation_id=correlation_id
        )

        return ProjectResponse(**project)

    except Exception as e:
        logger.error(f"Failed to create project: {e}", extra={"correlation_id": correlation_id})
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create project"
        )
```

## Distributed Tracing and Correlation

### Correlation ID Management
```python
# shared/utils/correlation.py
import uuid
from typing import Optional
from fastapi import Request, Header
from contextvars import ContextVar
import logging

# Context variable for correlation ID
correlation_id_context: ContextVar[Optional[str]] = ContextVar('correlation_id', default=None)

def generate_correlation_id() -> str:
    """Generate a new correlation ID"""
    return str(uuid.uuid4())

def get_correlation_id(
    request: Request = None,
    x_correlation_id: Optional[str] = Header(None, alias="X-Correlation-ID")
) -> str:
    """Get or generate correlation ID for request tracking"""
    # Try to get from header first
    if x_correlation_id:
        correlation_id_context.set(x_correlation_id)
        return x_correlation_id

    # Try to get from context
    existing_id = correlation_id_context.get()
    if existing_id:
        return existing_id

    # Generate new correlation ID
    new_id = generate_correlation_id()
    correlation_id_context.set(new_id)
    return new_id

def set_correlation_id(correlation_id: str) -> None:
    """Set correlation ID in context"""
    correlation_id_context.set(correlation_id)

def get_current_correlation_id() -> Optional[str]:
    """Get current correlation ID from context"""
    return correlation_id_context.get()

# Custom logging formatter to include correlation ID
class CorrelationFormatter(logging.Formatter):
    def format(self, record):
        correlation_id = get_current_correlation_id()
        if correlation_id:
            record.correlation_id = correlation_id
        else:
            record.correlation_id = "N/A"
        return super().format(record)

# Configure logging with correlation ID
def setup_correlation_logging():
    formatter = CorrelationFormatter(
        '%(asctime)s - %(name)s - %(levelname)s - [%(correlation_id)s] - %(message)s'
    )

    handler = logging.StreamHandler()
    handler.setFormatter(formatter)

    logger = logging.getLogger()
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
```

### Middleware for Request Tracing
```python
# shared/middleware/tracing.py
import time
from fastapi import Request, Response
from fastapi.middleware.base import BaseHTTPMiddleware
from ..utils.correlation import get_correlation_id, set_correlation_id
from ..monitoring.metrics import request_duration, request_counter
import logging

logger = logging.getLogger(__name__)

class TracingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        # Set up correlation ID for the request
        correlation_id = get_correlation_id(request)
        set_correlation_id(correlation_id)

        # Add correlation ID to response headers
        start_time = time.time()

        # Log request start
        logger.info(
            f"Request started: {request.method} {request.url.path}",
            extra={
                "method": request.method,
                "path": request.url.path,
                "correlation_id": correlation_id
            }
        )

        try:
            # Process request
            response: Response = await call_next(request)

            # Add correlation ID to response headers
            response.headers["X-Correlation-ID"] = correlation_id

            # Log request completion
            duration = time.time() - start_time
            logger.info(
                f"Request completed: {request.method} {request.url.path} - {response.status_code} - {duration:.3f}s",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration": duration,
                    "correlation_id": correlation_id
                }
            )

            # Record metrics
            request_duration.labels(
                method=request.method,
                endpoint=request.url.path,
                status=response.status_code
            ).observe(duration)

            request_counter.labels(
                method=request.method,
                endpoint=request.url.path,
                status=response.status_code
            ).inc()

            return response

        except Exception as e:
            duration = time.time() - start_time
            logger.error(
                f"Request failed: {request.method} {request.url.path} - {str(e)} - {duration:.3f}s",
                extra={
                    "method": request.method,
                    "path": request.url.path,
                    "error": str(e),
                    "duration": duration,
                    "correlation_id": correlation_id
                }
            )

            # Record error metrics
            request_counter.labels(
                method=request.method,
                endpoint=request.url.path,
                status=500
            ).inc()

            raise
```

## Error Handling and Standardization

### Standardized Error Response Format
```python
# shared/exceptions/service_errors.py
from typing import Optional, Dict, Any
from fastapi import HTTPException, status
from pydantic import BaseModel

class ErrorDetail(BaseModel):
    code: str
    message: str
    field: Optional[str] = None
    context: Optional[Dict[str, Any]] = None

class ServiceError(BaseModel):
    error: str
    details: list[ErrorDetail]
    correlation_id: Optional[str] = None
    timestamp: str
    service: str

class ServiceException(Exception):
    def __init__(
        self,
        message: str,
        error_code: str,
        status_code: int = status.HTTP_500_INTERNAL_SERVER_ERROR,
        details: Optional[list[ErrorDetail]] = None
    ):
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.details = details or []
        super().__init__(message)

class ServiceUnavailableException(ServiceException):
    def __init__(self, service_name: str):
        super().__init__(
            f"Service {service_name} is currently unavailable",
            "SERVICE_UNAVAILABLE",
            status.HTTP_503_SERVICE_UNAVAILABLE
        )

class AuthenticationException(ServiceException):
    def __init__(self, message: str = "Authentication failed"):
        super().__init__(
            message,
            "AUTHENTICATION_FAILED",
            status.HTTP_401_UNAUTHORIZED
        )

class AuthorizationException(ServiceException):
    def __init__(self, message: str = "Insufficient permissions"):
        super().__init__(
            message,
            "AUTHORIZATION_FAILED",
            status.HTTP_403_FORBIDDEN
        )

# Exception handler for FastAPI
async def service_exception_handler(request: Request, exc: ServiceException):
    from ..utils.correlation import get_current_correlation_id
    from datetime import datetime

    error_response = ServiceError(
        error=exc.error_code,
        details=exc.details,
        correlation_id=get_current_correlation_id(),
        timestamp=datetime.utcnow().isoformat(),
        service=request.app.title
    )

    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.dict()
    )
```

## Health Checks and Service Discovery

### Comprehensive Health Checks
```python
# shared/monitoring/health.py
from typing import Dict, Any, List
from enum import Enum
import asyncio
import time
from ..external_services import DataServiceClient, NotificationServiceClient

class HealthStatus(Enum):
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"

class HealthCheck:
    def __init__(self, name: str, check_func, timeout: float = 5.0):
        self.name = name
        self.check_func = check_func
        self.timeout = timeout

class HealthMonitor:
    def __init__(self):
        self.checks: List[HealthCheck] = []
        self.external_services = {}

    def add_check(self, name: str, check_func, timeout: float = 5.0):
        """Add a health check"""
        self.checks.append(HealthCheck(name, check_func, timeout))

    def add_external_service(self, name: str, client):
        """Add external service for health monitoring"""
        self.external_services[name] = client

    async def run_health_checks(self) -> Dict[str, Any]:
        """Run all health checks and return status"""
        results = {}
        overall_status = HealthStatus.HEALTHY

        # Run internal health checks
        for check in self.checks:
            try:
                start_time = time.time()
                result = await asyncio.wait_for(check.check_func(), timeout=check.timeout)
                duration = time.time() - start_time

                results[check.name] = {
                    "status": HealthStatus.HEALTHY.value,
                    "duration_ms": round(duration * 1000, 2),
                    "details": result if isinstance(result, dict) else {"status": "ok"}
                }
            except asyncio.TimeoutError:
                results[check.name] = {
                    "status": HealthStatus.UNHEALTHY.value,
                    "error": "Health check timeout",
                    "timeout_ms": check.timeout * 1000
                }
                overall_status = HealthStatus.UNHEALTHY
            except Exception as e:
                results[check.name] = {
                    "status": HealthStatus.UNHEALTHY.value,
                    "error": str(e)
                }
                overall_status = HealthStatus.UNHEALTHY

        # Check external services
        for service_name, client in self.external_services.items():
            try:
                start_time = time.time()
                is_healthy = await asyncio.wait_for(client.health_check(), timeout=5.0)
                duration = time.time() - start_time

                if is_healthy:
                    results[f"external_{service_name}"] = {
                        "status": HealthStatus.HEALTHY.value,
                        "duration_ms": round(duration * 1000, 2),
                        "circuit_breaker": client.get_stats()
                    }
                else:
                    results[f"external_{service_name}"] = {
                        "status": HealthStatus.DEGRADED.value,
                        "duration_ms": round(duration * 1000, 2),
                        "circuit_breaker": client.get_stats()
                    }
                    if overall_status == HealthStatus.HEALTHY:
                        overall_status = HealthStatus.DEGRADED

            except Exception as e:
                results[f"external_{service_name}"] = {
                    "status": HealthStatus.UNHEALTHY.value,
                    "error": str(e),
                    "circuit_breaker": client.get_stats()
                }
                overall_status = HealthStatus.UNHEALTHY

        return {
            "status": overall_status.value,
            "timestamp": time.time(),
            "checks": results
        }
```

## Standards Reference
- **Dependency Versions**: Always use the latest stable versions of all dependencies, libraries, and tools
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Communication Infrastructure
```
shared/
├── http_client/
│   ├── base_client.py          # HTTP client with circuit breaker
│   └── circuit_breaker.py      # Circuit breaker implementation
├── middleware/
│   ├── service_auth.py         # JWT token propagation
│   └── tracing.py              # Distributed tracing middleware
├── utils/
│   ├── correlation.py          # Correlation ID management
│   └── retry.py                # Retry utilities
├── exceptions/
│   └── service_errors.py       # Standardized error handling
└── monitoring/
    └── health.py               # Health check framework

api-service/src/infrastructure/external_services/
├── data_service_client.py      # Data service HTTP client
├── notification_service_client.py # Notification service client
└── base.py                     # Common service client patterns

data-service/src/infrastructure/external_services/
├── notification_service_client.py # Notification service client
└── vault_client.py             # Vault integration client
```

### Features Implemented
- ✅ HTTP client with circuit breaker pattern
- ✅ JWT token propagation between services
- ✅ Distributed tracing with correlation IDs
- ✅ Exponential backoff retry logic
- ✅ Standardized error handling and response format
- ✅ Comprehensive health checks for service dependencies
- ✅ Connection pooling and resource optimization
- ✅ Service discovery via Kubernetes DNS
- ✅ Performance monitoring and metrics

## Acceptance Criteria

### Communication Reliability
- [ ] Services communicate successfully via HTTP REST APIs
- [ ] Circuit breakers prevent cascading failures during service outages
- [ ] Retry logic handles transient failures with exponential backoff
- [ ] Connection pooling optimizes resource utilization

### Authentication & Security
- [ ] JWT tokens properly propagated and validated between services
- [ ] Service-to-service authentication prevents unauthorized access
- [ ] Token expiration handled gracefully with automatic renewal
- [ ] Security headers included in all inter-service requests

### Observability
- [ ] Correlation IDs trace requests across all service boundaries
- [ ] Distributed tracing provides end-to-end request visibility
- [ ] Health checks accurately reflect service and dependency status
- [ ] Error responses follow consistent format across all services

### Performance
- [ ] Inter-service calls complete in under 50ms within cluster
- [ ] Circuit breaker decisions execute in under 1ms
- [ ] Connection reuse reduces overhead for frequent service calls
- [ ] Performance metrics available for all service communication patterns

This inter-service communication implementation ensures robust, secure, and observable communication between all backend microservices in the BlockSecOps Platform.