# Sprint 9: Performance Optimization & Enterprise Features

**Duration**: Weeks 17-18 (2 weeks)
**Status**: Planning
**Technical Milestone**: Production-ready performance with enterprise capabilities

---

## Overview

Sprint 9 elevates the platform to enterprise production standards through comprehensive performance optimization, advanced scalability features, and enterprise-grade authentication and governance systems. This sprint ensures the platform can handle enterprise-scale loads while providing the security and administrative controls required by large organizations.

### Key Objectives

1. **Performance Optimization**: Achieve enterprise-scale performance through intelligent caching, database optimization, and CDN integration
2. **Auto-Scaling**: Implement predictive and reactive scaling for all platform components
3. **Enterprise Authentication**: Deploy SAML 2.0, MFA, and LDAP integration for enterprise SSO
4. **Administration & Governance**: Build comprehensive administrative controls and audit systems
5. **Reliability Engineering**: Implement circuit breakers, graceful degradation, and fault tolerance
6. **Production Validation**: Comprehensive load testing and performance validation

---

## Technical Milestone

**Deliverable**: Production-ready platform with enterprise-scale performance and security

**Success Criteria**:
- Platform handles 1000+ concurrent users without degradation
- API response times <100ms at P95 under load
- Auto-scaling responds to load changes within 30 seconds
- SAML SSO working with major identity providers
- MFA enforcement across all authentication methods
- Granular permission system operational
- All acceptance criteria met

---

## Epic 1: Performance Optimization

### Epic Goal
Optimize platform performance for enterprise-scale operations.

### Tasks

#### Task 9.1: Advanced Horizontal Pod Autoscaling

**Story**: As a platform operator, I need intelligent auto-scaling so that the platform automatically handles load variations efficiently.

**Acceptance Criteria**:
- [ ] HPA configured for all services with custom metrics
- [ ] CPU-based scaling policies implemented
- [ ] Memory-based scaling policies implemented
- [ ] Custom metric scaling (request rate, queue depth)
- [ ] Predictive scaling based on historical patterns
- [ ] Scale-down delay configuration to prevent flapping
- [ ] Vertical Pod Autoscaler (VPA) for resource optimization
- [ ] Tests for scaling behavior

**Implementation Details**:
```yaml
# kubernetes/base/api-service/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-service
  minReplicas: 3
  maxReplicas: 50
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 4
        periodSeconds: 30
      selectPolicy: Max
```

**Custom Metrics**:
```python
# src/infrastructure/monitoring/custom_metrics.py
class CustomMetricsExporter:
    def export_request_rate_metric(self, service_name: str, rate: float):
        """Export request rate for HPA"""
        self.prometheus_client.gauge(
            f'{service_name}_http_requests_per_second',
            rate,
            labels={'service': service_name}
        )

    def export_queue_depth_metric(self, queue_name: str, depth: int):
        """Export queue depth for worker scaling"""
        self.prometheus_client.gauge(
            f'{queue_name}_queue_depth',
            depth,
            labels={'queue': queue_name}
        )
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 9.2: Intelligent Database Connection Pooling

**Story**: As a database administrator, I need optimized connection pooling so that we maximize database performance under high load.

**Acceptance Criteria**:
- [ ] PgBouncer deployed in transaction pooling mode
- [ ] Connection pool sizing optimized per service
- [ ] Connection pool monitoring and metrics
- [ ] Read replica routing for read-heavy queries
- [ ] Query result caching for common queries
- [ ] Prepared statement caching
- [ ] Connection pool health checks
- [ ] Tests for connection pool behavior

**PgBouncer Configuration**:
```ini
# pgbouncer.ini
[databases]
platform = host=postgres-primary port=5432 dbname=platform pool_size=25
platform_read = host=postgres-replica port=5432 dbname=platform pool_size=50

[pgbouncer]
pool_mode = transaction
max_client_conn = 1000
default_pool_size = 25
reserve_pool_size = 5
reserve_pool_timeout = 3
max_db_connections = 100
max_user_connections = 100
server_idle_timeout = 600
server_lifetime = 3600
server_connect_timeout = 15
query_timeout = 0
stats_period = 60
```

**SQLAlchemy Configuration**:
```python
# src/infrastructure/database/connection.py
class DatabaseConnectionManager:
    def create_engine(self, connection_string: str, read_only: bool = False):
        """Create optimized database engine"""
        pool_size = 50 if read_only else 25
        return create_engine(
            connection_string,
            pool_size=pool_size,
            max_overflow=10,
            pool_pre_ping=True,
            pool_recycle=3600,
            echo=False,
            connect_args={
                'connect_timeout': 10,
                'options': '-c statement_timeout=30000'
            }
        )
```

**Read Replica Routing**:
```python
# src/infrastructure/database/routing.py
class DatabaseRouter:
    def route_query(self, query_type: str) -> Engine:
        """Route query to appropriate database"""
        if query_type in ['SELECT', 'COUNT'] and not in_transaction():
            return self.read_replica_engine
        return self.primary_engine
```

**Estimated Time**: 14 hours

**Dependencies**: None

---

#### Task 9.3: Multi-Tier Caching Strategy

**Story**: As a performance engineer, I need a comprehensive caching strategy so that we minimize database load and improve response times.

**Acceptance Criteria**:
- [ ] Application-level caching with TTL management
- [ ] Redis caching layer implemented
- [ ] CDN caching for static assets
- [ ] Cache warming strategy for common queries
- [ ] Cache invalidation on data updates
- [ ] Cache hit rate monitoring
- [ ] Cache-aside pattern implementation
- [ ] Tests for caching behavior

**Caching Layers**:
```python
# src/infrastructure/caching/cache_manager.py
class MultiTierCacheManager:
    def __init__(self):
        self.l1_cache = LRUCache(maxsize=1000)  # In-memory
        self.l2_cache = RedisCache()  # Distributed
        self.l3_cache = DatabaseCache()  # Persistent

    async def get(self, key: str) -> Optional[Any]:
        """Get value from multi-tier cache"""
        # L1: In-memory cache
        value = self.l1_cache.get(key)
        if value is not None:
            return value

        # L2: Redis cache
        value = await self.l2_cache.get(key)
        if value is not None:
            self.l1_cache.set(key, value)
            return value

        # L3: Database
        value = await self.l3_cache.get(key)
        if value is not None:
            await self.l2_cache.set(key, value, ttl=3600)
            self.l1_cache.set(key, value)

        return value

    async def set(self, key: str, value: Any, ttl: int = 3600):
        """Set value in all cache tiers"""
        self.l1_cache.set(key, value)
        await self.l2_cache.set(key, value, ttl=ttl)
        await self.l3_cache.set(key, value)

    async def invalidate(self, key: str):
        """Invalidate cache across all tiers"""
        self.l1_cache.delete(key)
        await self.l2_cache.delete(key)
        await self.l3_cache.delete(key)
```

**Cache Warming**:
```python
# src/infrastructure/caching/cache_warmer.py
class CacheWarmer:
    async def warm_common_queries(self):
        """Pre-populate cache with common queries"""
        # Warm user sessions
        active_users = await self.user_repo.get_active_users()
        for user in active_users:
            await self.cache.set(f'user:{user.id}', user, ttl=3600)

        # Warm finding statistics
        stats = await self.analytics_service.get_global_stats()
        await self.cache.set('global:stats', stats, ttl=300)

        # Warm workflow states
        states = await self.workflow_repo.get_all_states()
        await self.cache.set('workflow:states', states, ttl=7200)
```

**Cache Invalidation**:
```python
# src/domain/events/cache_invalidation.py
class CacheInvalidationHandler:
    async def handle_finding_updated(self, event: FindingUpdatedEvent):
        """Invalidate caches when finding updated"""
        await self.cache.invalidate(f'finding:{event.finding_id}')
        await self.cache.invalidate(f'user:{event.user_id}:findings')
        await self.cache.invalidate('global:stats')
```

**Estimated Time**: 16 hours

**Dependencies**: None

---

#### Task 9.4: Database Query Optimization

**Story**: As a database administrator, I need optimized queries and indexes so that database operations remain fast under load.

**Acceptance Criteria**:
- [ ] Query analysis and slow query logging enabled
- [ ] Indexes created for all common query patterns
- [ ] Composite indexes for complex queries
- [ ] Partial indexes for filtered queries
- [ ] Query plan analysis and optimization
- [ ] N+1 query elimination
- [ ] Batch query optimization
- [ ] Query performance tests

**Index Strategy**:
```sql
-- Findings table indexes
CREATE INDEX CONCURRENTLY idx_findings_organization ON findings(organization_id);
CREATE INDEX CONCURRENTLY idx_findings_status ON findings(status) WHERE deleted_at IS NULL;
CREATE INDEX CONCURRENTLY idx_findings_severity ON findings(severity);
CREATE INDEX CONCURRENTLY idx_findings_assigned ON findings(assigned_to) WHERE assigned_to IS NOT NULL;
CREATE INDEX CONCURRENTLY idx_findings_created ON findings(created_at DESC);

-- Composite indexes for common filters
CREATE INDEX CONCURRENTLY idx_findings_org_status_severity
ON findings(organization_id, status, severity)
WHERE deleted_at IS NULL;

-- Partial index for active findings
CREATE INDEX CONCURRENTLY idx_findings_active
ON findings(organization_id, created_at DESC)
WHERE status NOT IN ('closed', 'resolved') AND deleted_at IS NULL;

-- GIN index for full-text search
CREATE INDEX CONCURRENTLY idx_findings_search
ON findings USING gin(to_tsvector('english', title || ' ' || description));

-- Index on JSONB columns
CREATE INDEX CONCURRENTLY idx_findings_metadata
ON findings USING gin(metadata jsonb_path_ops);
```

**Query Optimization**:
```python
# src/infrastructure/database/repositories/finding_repository.py
class FindingRepository:
    async def get_findings_with_details(
        self,
        organization_id: UUID,
        filters: FindingFilters
    ) -> List[Finding]:
        """Optimized query with eager loading"""
        query = (
            select(Finding)
            .options(
                joinedload(Finding.assignees),
                joinedload(Finding.comments).joinedload(Comment.user),
                selectinload(Finding.workflow_history)
            )
            .where(Finding.organization_id == organization_id)
            .where(Finding.deleted_at.is_(None))
        )

        # Apply filters efficiently
        if filters.severity:
            query = query.where(Finding.severity.in_(filters.severity))
        if filters.status:
            query = query.where(Finding.status.in_(filters.status))

        # Use index for sorting
        query = query.order_by(Finding.created_at.desc())

        # Limit results
        query = query.limit(filters.limit).offset(filters.offset)

        result = await self.session.execute(query)
        return result.unique().scalars().all()
```

**Estimated Time**: 14 hours

**Dependencies**: None

---

#### Task 9.5: CloudFront CDN Optimization

**Story**: As a DevOps engineer, I need CDN optimization so that global users experience fast load times.

**Acceptance Criteria**:
- [ ] CloudFront distribution configured for all static assets
- [ ] Cache behaviors optimized per content type
- [ ] Compression enabled (Gzip, Brotli)
- [ ] HTTP/2 and HTTP/3 support enabled
- [ ] Origin shield configured for cache optimization
- [ ] Custom error pages configured
- [ ] Cache invalidation automation
- [ ] CDN performance monitoring

**CloudFront Configuration**:
```yaml
# terraform/cloudfront.tf
resource "aws_cloudfront_distribution" "platform" {
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  price_class         = "PriceClass_All"

  origin {
    domain_name = aws_s3_bucket.static_assets.bucket_regional_domain_name
    origin_id   = "S3-static-assets"
    origin_shield {
      enabled              = true
      origin_shield_region = "us-east-1"
    }

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.platform.cloudfront_access_identity_path
    }
  }

  origin {
    domain_name = "api.platform.com"
    origin_id   = "API"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-static-assets"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400
    max_ttl     = 31536000
  }

  # JavaScript bundles
  ordered_cache_behavior {
    path_pattern           = "*.js"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-static-assets"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 31536000
    default_ttl = 31536000
    max_ttl     = 31536000
  }

  # API requests
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "API"
    compress               = true
    viewer_protocol_policy = "https-only"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Accept", "Content-Type"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }
}
```

**Cache Invalidation**:
```python
# src/infrastructure/cdn/cloudfront_service.py
class CloudFrontService:
    async def invalidate_cache(self, paths: List[str]):
        """Invalidate CloudFront cache for specified paths"""
        self.cloudfront_client.create_invalidation(
            DistributionId=self.distribution_id,
            InvalidationBatch={
                'Paths': {
                    'Quantity': len(paths),
                    'Items': paths
                },
                'CallerReference': str(uuid.uuid4())
            }
        )
```

**Estimated Time**: 10 hours

**Dependencies**: None

---

## Epic 2: Scalability & Reliability

### Epic Goal
Ensure platform reliability and graceful degradation under all conditions.

### Tasks

#### Task 9.6: Comprehensive Load Testing Suite

**Story**: As a QA engineer, I need comprehensive load testing so that we validate platform performance under enterprise loads.

**Acceptance Criteria**:
- [ ] Load testing framework set up (Locust/K6)
- [ ] Realistic user behavior scenarios implemented
- [ ] Concurrent user simulation (100, 500, 1000, 2000)
- [ ] Ramp-up and steady-state testing
- [ ] Spike testing for sudden load increases
- [ ] Soak testing for extended periods
- [ ] Performance metrics collection
- [ ] Load test reports and analysis

**Load Testing Scenarios**:
```python
# tests/load/locustfile.py
from locust import HttpUser, task, between

class PlatformUser(HttpUser):
    wait_time = between(1, 5)

    def on_start(self):
        """Login and get auth token"""
        response = self.client.post("/api/v1/auth/login", json={
            "username": "testuser",
            "password": "password"
        })
        self.token = response.json()["access_token"]
        self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(10)
    def view_dashboard(self):
        """View dashboard - most common action"""
        self.client.get("/api/v1/dashboard", headers=self.headers)

    @task(5)
    def list_findings(self):
        """List findings with filters"""
        self.client.get(
            "/api/v1/findings?severity=critical&status=open",
            headers=self.headers
        )

    @task(3)
    def view_finding_details(self):
        """View finding details"""
        self.client.get("/api/v1/findings/123", headers=self.headers)

    @task(2)
    def add_comment(self):
        """Add comment to finding"""
        self.client.post(
            "/api/v1/findings/123/comments",
            json={"content": "Test comment"},
            headers=self.headers
        )

    @task(1)
    def submit_analysis(self):
        """Submit contract for analysis"""
        self.client.post(
            "/api/v1/contracts/analyze",
            files={"file": ("test.sol", "contract Test {}")},
            headers=self.headers
        )
```

**Load Test Execution**:
```bash
# Baseline test
locust -f tests/load/locustfile.py --users 100 --spawn-rate 10 --run-time 5m

# Stress test
locust -f tests/load/locustfile.py --users 1000 --spawn-rate 50 --run-time 30m

# Spike test
locust -f tests/load/locustfile.py --users 2000 --spawn-rate 200 --run-time 10m

# Soak test
locust -f tests/load/locustfile.py --users 500 --spawn-rate 25 --run-time 2h
```

**Estimated Time**: 16 hours

**Dependencies**: All performance optimization tasks

---

#### Task 9.7: Circuit Breakers for External Services

**Story**: As a reliability engineer, I need circuit breakers so that failures in external services don't cascade to the entire platform.

**Acceptance Criteria**:
- [ ] Circuit breaker library integrated (Pybreaker)
- [ ] Circuit breakers for all external APIs
- [ ] Configurable failure thresholds
- [ ] Automatic recovery testing
- [ ] Circuit breaker state monitoring
- [ ] Fallback responses configured
- [ ] Circuit breaker metrics in dashboards
- [ ] Tests for circuit breaker behavior

**Circuit Breaker Implementation**:
```python
# src/infrastructure/resilience/circuit_breaker.py
from pybreaker import CircuitBreaker, CircuitBreakerError
from dataclasses import dataclass

@dataclass
class CircuitBreakerConfig:
    fail_max: int = 5
    timeout_duration: int = 60
    expected_exception: type = Exception

class ResilientExternalService:
    def __init__(self, service_name: str, config: CircuitBreakerConfig):
        self.breaker = CircuitBreaker(
            fail_max=config.fail_max,
            timeout_duration=config.timeout_duration,
            expected_exception=config.expected_exception,
            name=service_name
        )
        self.service_name = service_name

    @property
    def current_state(self) -> str:
        """Get circuit breaker state"""
        return self.breaker.current_state

    async def call_with_fallback(self, fn, fallback_fn, *args, **kwargs):
        """Call external service with circuit breaker and fallback"""
        try:
            return await self.breaker.call_async(fn, *args, **kwargs)
        except CircuitBreakerError:
            logger.warning(
                f"Circuit breaker open for {self.service_name}, using fallback"
            )
            return await fallback_fn(*args, **kwargs)

# Usage example
class MythrilService:
    def __init__(self):
        self.circuit_breaker = ResilientExternalService(
            "mythril_api",
            CircuitBreakerConfig(fail_max=3, timeout_duration=30)
        )

    async def analyze_contract(self, contract_code: str):
        """Analyze contract with circuit breaker protection"""
        return await self.circuit_breaker.call_with_fallback(
            self._call_mythril_api,
            self._fallback_analysis,
            contract_code
        )

    async def _call_mythril_api(self, contract_code: str):
        """Actual API call"""
        response = await self.http_client.post(
            f"{self.api_url}/analyze",
            json={"code": contract_code}
        )
        return response.json()

    async def _fallback_analysis(self, contract_code: str):
        """Fallback when Mythril is unavailable"""
        return {
            "status": "degraded",
            "message": "Mythril temporarily unavailable",
            "findings": []
        }
```

**Monitoring**:
```python
# src/infrastructure/monitoring/circuit_breaker_metrics.py
class CircuitBreakerMetrics:
    def record_state_change(self, service: str, state: str):
        """Record circuit breaker state change"""
        self.prometheus.gauge(
            'circuit_breaker_state',
            self._state_to_int(state),
            labels={'service': service}
        )

    def _state_to_int(self, state: str) -> int:
        return {'closed': 0, 'half-open': 1, 'open': 2}.get(state, -1)
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 9.8: Graceful Degradation Strategies

**Story**: As a platform operator, I need graceful degradation so that the platform remains functional even when some services fail.

**Acceptance Criteria**:
- [ ] Service dependency mapping completed
- [ ] Degraded mode for each service defined
- [ ] Fallback implementations for critical paths
- [ ] User notification of degraded features
- [ ] Automatic recovery when services restore
- [ ] Degradation mode monitoring
- [ ] Tests for all degradation scenarios
- [ ] Documentation of degradation behaviors

**Degradation Strategies**:
```python
# src/domain/services/degradation_manager.py
class DegradationManager:
    def __init__(self):
        self.service_health = {}
        self.degradation_rules = self._load_degradation_rules()

    async def get_feature_availability(self, feature: str) -> FeatureStatus:
        """Check if feature is available or degraded"""
        dependencies = self.degradation_rules[feature]['dependencies']

        # Check all dependencies
        unhealthy = []
        for dep in dependencies:
            if not await self.is_service_healthy(dep):
                unhealthy.append(dep)

        if not unhealthy:
            return FeatureStatus.AVAILABLE

        # Check if feature can work in degraded mode
        critical_deps = self.degradation_rules[feature]['critical']
        if any(dep in critical_deps for dep in unhealthy):
            return FeatureStatus.UNAVAILABLE

        return FeatureStatus.DEGRADED

    async def execute_with_degradation(
        self,
        feature: str,
        primary_fn,
        degraded_fn,
        *args,
        **kwargs
    ):
        """Execute function with degradation support"""
        status = await self.get_feature_availability(feature)

        if status == FeatureStatus.AVAILABLE:
            return await primary_fn(*args, **kwargs)
        elif status == FeatureStatus.DEGRADED:
            logger.warning(f"Feature {feature} running in degraded mode")
            return await degraded_fn(*args, **kwargs)
        else:
            raise FeatureUnavailableError(f"Feature {feature} is unavailable")

# Degradation rules configuration
DEGRADATION_RULES = {
    'contract_analysis': {
        'dependencies': ['mythril', 'slither', 'aderyn', 'parser'],
        'critical': ['parser'],  # Only parser is critical
        'degraded_behavior': 'run_with_available_tools'
    },
    'real_time_notifications': {
        'dependencies': ['redis', 'websocket'],
        'critical': [],
        'degraded_behavior': 'polling_fallback'
    },
    'dashboard_analytics': {
        'dependencies': ['analytics_service', 'redis'],
        'critical': [],
        'degraded_behavior': 'cached_data_only'
    }
}
```

**Usage Example**:
```python
# src/application/services/analysis_service.py
class AnalysisService:
    async def analyze_contract(self, contract: Contract):
        """Analyze contract with degradation support"""
        return await self.degradation_manager.execute_with_degradation(
            'contract_analysis',
            self._full_analysis,
            self._degraded_analysis,
            contract
        )

    async def _full_analysis(self, contract: Contract):
        """Run all analysis tools"""
        results = await asyncio.gather(
            self.mythril.analyze(contract),
            self.slither.analyze(contract),
            self.aderyn.analyze(contract)
        )
        return self.aggregate_results(results)

    async def _degraded_analysis(self, contract: Contract):
        """Run only available tools"""
        available_tools = await self.get_available_tools()
        results = await asyncio.gather(*[
            tool.analyze(contract) for tool in available_tools
        ])
        return self.aggregate_results(results, degraded=True)
```

**Estimated Time**: 14 hours

**Dependencies**: Task 9.7

---

#### Task 9.9: Dynamic Rate Limiting

**Story**: As a security engineer, I need intelligent rate limiting so that we prevent abuse while allowing legitimate high-volume users.

**Acceptance Criteria**:
- [ ] Rate limiting middleware implemented
- [ ] Per-user and per-organization rate limits
- [ ] Dynamic rate adjustment based on subscription tier
- [ ] IP-based rate limiting for unauthenticated endpoints
- [ ] Rate limit headers in responses
- [ ] Redis-backed distributed rate limiting
- [ ] Rate limit bypass for internal services
- [ ] Tests for rate limiting scenarios

**Rate Limiting Implementation**:
```python
# src/infrastructure/middleware/rate_limiting.py
from slowapi import Limiter
from slowapi.util import get_remote_address

class DynamicRateLimiter:
    def __init__(self):
        self.limiter = Limiter(
            key_func=get_remote_address,
            storage_uri="redis://redis:6379"
        )
        self.tier_limits = self._load_tier_limits()

    def get_user_limit(self, user: User) -> str:
        """Get rate limit string based on user tier"""
        tier = user.organization.subscription_tier
        return self.tier_limits.get(tier, "100/hour")

    def apply_limit(self, endpoint_type: str):
        """Decorator to apply rate limits"""
        def decorator(func):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                user = get_current_user()
                limit = self.get_user_limit(user)

                # Apply limit
                if not await self.check_limit(user.id, limit):
                    raise RateLimitExceeded(
                        f"Rate limit exceeded: {limit}",
                        retry_after=await self.get_retry_after(user.id)
                    )

                return await func(*args, **kwargs)
            return wrapper
        return decorator

# Rate limit tiers
TIER_LIMITS = {
    'free': {
        'api_calls': '100/hour',
        'analyses': '10/day',
        'exports': '5/day'
    },
    'professional': {
        'api_calls': '1000/hour',
        'analyses': '100/day',
        'exports': '50/day'
    },
    'enterprise': {
        'api_calls': '10000/hour',
        'analyses': 'unlimited',
        'exports': 'unlimited'
    }
}

# FastAPI integration
@app.post("/api/v1/contracts/analyze")
@rate_limiter.apply_limit("analyses")
async def analyze_contract(contract: ContractUpload):
    """Analyze contract with rate limiting"""
    return await analysis_service.analyze(contract)
```

**Rate Limit Headers**:
```python
# src/infrastructure/middleware/rate_limit_headers.py
class RateLimitHeaderMiddleware:
    async def __call__(self, request: Request, call_next):
        response = await call_next(request)

        if hasattr(request.state, 'rate_limit_info'):
            info = request.state.rate_limit_info
            response.headers['X-RateLimit-Limit'] = str(info.limit)
            response.headers['X-RateLimit-Remaining'] = str(info.remaining)
            response.headers['X-RateLimit-Reset'] = str(info.reset_time)

        return response
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 9.10: Predictive Scaling

**Story**: As a platform operator, I need predictive scaling so that we proactively scale before load increases.

**Acceptance Criteria**:
- [ ] Historical load pattern analysis
- [ ] Time-series forecasting model (Prophet/ARIMA)
- [ ] Scheduled scaling for known patterns
- [ ] Anomaly detection for unusual patterns
- [ ] Integration with HPA
- [ ] Scaling prediction accuracy metrics
- [ ] Dashboard for scaling predictions
- [ ] Tests for scaling algorithm

**Predictive Scaling**:
```python
# src/infrastructure/scaling/predictive_scaler.py
from prophet import Prophet
import pandas as pd

class PredictiveScaler:
    def __init__(self):
        self.model = Prophet(
            daily_seasonality=True,
            weekly_seasonality=True,
            yearly_seasonality=False
        )
        self.scaling_threshold = 0.70  # Scale at 70% predicted capacity

    async def analyze_historical_load(self, days: int = 30):
        """Analyze historical load patterns"""
        metrics = await self.prometheus.query_range(
            'sum(rate(http_requests_total[5m]))',
            start=datetime.now() - timedelta(days=days),
            end=datetime.now(),
            step='5m'
        )

        df = pd.DataFrame(metrics, columns=['ds', 'y'])
        self.model.fit(df)

    async def predict_future_load(self, hours: int = 24):
        """Predict load for next N hours"""
        future = self.model.make_future_dataframe(periods=hours, freq='H')
        forecast = self.model.predict(future)
        return forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']]

    async def calculate_required_replicas(
        self,
        current_replicas: int,
        current_load: float,
        predicted_load: float
    ) -> int:
        """Calculate required replicas based on prediction"""
        load_increase_ratio = predicted_load / current_load
        required_replicas = int(current_replicas * load_increase_ratio)

        # Add buffer
        buffered_replicas = int(required_replicas * 1.2)

        return max(buffered_replicas, current_replicas)

    async def schedule_scaling(self):
        """Schedule scaling based on predictions"""
        predictions = await self.predict_future_load(hours=4)

        for idx, row in predictions.iterrows():
            predicted_time = row['ds']
            predicted_load = row['yhat']

            current_capacity = await self.get_current_capacity()
            predicted_capacity = predicted_load / current_capacity

            if predicted_capacity > self.scaling_threshold:
                await self.schedule_scale_up(
                    time=predicted_time,
                    replicas=await self.calculate_required_replicas(
                        await self.get_current_replicas(),
                        await self.get_current_load(),
                        predicted_load
                    )
                )
```

**Estimated Time**: 16 hours

**Dependencies**: Task 9.1

---

## Epic 3: Enterprise Authentication

### Epic Goal
Implement enterprise-grade authentication and identity management.

### Tasks

#### Task 9.11: SAML 2.0 Integration

**Story**: As an enterprise IT administrator, I need SAML SSO so that our employees can use their corporate credentials.

**Acceptance Criteria**:
- [ ] SAML 2.0 service provider implemented
- [ ] Integration with Okta, Azure AD, OneLogin
- [ ] SAML metadata configuration
- [ ] Attribute mapping (email, name, groups)
- [ ] Just-in-Time (JIT) user provisioning
- [ ] SAML assertion validation
- [ ] Multi-tenant SAML configuration
- [ ] Tests for SAML authentication flow

**SAML Implementation**:
```python
# src/infrastructure/auth/saml_provider.py
from onelogin.saml2.auth import OneLogin_Saml2_Auth
from onelogin.saml2.settings import OneLogin_Saml2_Settings

class SAMLAuthProvider:
    def __init__(self, organization: Organization):
        self.organization = organization
        self.settings = self._load_saml_settings(organization)

    def _load_saml_settings(self, org: Organization) -> dict:
        """Load SAML settings for organization"""
        return {
            "strict": True,
            "debug": False,
            "sp": {
                "entityId": f"https://platform.com/saml/{org.id}",
                "assertionConsumerService": {
                    "url": f"https://platform.com/api/v1/auth/saml/acs/{org.id}",
                    "binding": "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
                },
                "singleLogoutService": {
                    "url": f"https://platform.com/api/v1/auth/saml/sls/{org.id}",
                    "binding": "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                },
                "x509cert": org.saml_config.sp_cert,
                "privateKey": org.saml_config.sp_key
            },
            "idp": {
                "entityId": org.saml_config.idp_entity_id,
                "singleSignOnService": {
                    "url": org.saml_config.idp_sso_url,
                    "binding": "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
                },
                "x509cert": org.saml_config.idp_cert
            }
        }

    async def initiate_sso(self, request: Request):
        """Initiate SAML SSO flow"""
        auth = OneLogin_Saml2_Auth(request, self.settings)
        return auth.login(return_to="https://platform.com/dashboard")

    async def process_assertion(self, request: Request):
        """Process SAML assertion"""
        auth = OneLogin_Saml2_Auth(request, self.settings)
        auth.process_response()

        if not auth.is_authenticated():
            raise SAMLAuthenticationError(auth.get_errors())

        # Extract user attributes
        attributes = auth.get_attributes()
        saml_user_id = auth.get_nameid()

        # JIT provisioning
        user = await self.provision_user(
            email=attributes.get('email')[0],
            first_name=attributes.get('firstName')[0],
            last_name=attributes.get('lastName')[0],
            saml_id=saml_user_id,
            groups=attributes.get('groups', [])
        )

        return user

    async def provision_user(
        self,
        email: str,
        first_name: str,
        last_name: str,
        saml_id: str,
        groups: List[str]
    ) -> User:
        """JIT user provisioning"""
        user = await self.user_repo.find_by_email(email)

        if not user:
            user = await self.user_repo.create(User(
                email=email,
                first_name=first_name,
                last_name=last_name,
                saml_id=saml_id,
                organization_id=self.organization.id,
                auth_provider='saml'
            ))

        # Sync group memberships
        await self.sync_groups(user, groups)

        return user
```

**API Endpoints**:
```python
@app.get("/api/v1/auth/saml/login/{org_id}")
async def saml_login(org_id: UUID):
    """Initiate SAML SSO"""
    org = await org_repo.get(org_id)
    saml_provider = SAMLAuthProvider(org)
    return await saml_provider.initiate_sso(request)

@app.post("/api/v1/auth/saml/acs/{org_id}")
async def saml_assertion_consumer(org_id: UUID):
    """SAML Assertion Consumer Service"""
    org = await org_repo.get(org_id)
    saml_provider = SAMLAuthProvider(org)
    user = await saml_provider.process_assertion(request)

    # Create session
    token = await create_access_token(user)
    return {"access_token": token, "user": user}
```

**Estimated Time**: 20 hours

**Dependencies**: None

---

#### Task 9.12: Multi-Factor Authentication (MFA)

**Story**: As a security-conscious user, I need MFA so that my account remains secure even if my password is compromised.

**Acceptance Criteria**:
- [ ] TOTP (Time-based One-Time Password) support
- [ ] SMS-based MFA integration
- [ ] Hardware key support (WebAuthn/FIDO2)
- [ ] Backup codes generation
- [ ] MFA enrollment flow
- [ ] MFA enforcement policies
- [ ] Recovery procedures
- [ ] Tests for all MFA methods

**TOTP Implementation**:
```python
# src/infrastructure/auth/mfa/totp_provider.py
import pyotp
import qrcode
from io import BytesIO

class TOTPProvider:
    def generate_secret(self, user: User) -> str:
        """Generate TOTP secret for user"""
        secret = pyotp.random_base32()
        await self.user_repo.update_mfa_secret(user.id, secret)
        return secret

    def generate_qr_code(self, user: User, secret: str) -> bytes:
        """Generate QR code for TOTP setup"""
        totp_uri = pyotp.totp.TOTP(secret).provisioning_uri(
            name=user.email,
            issuer_name="Security Platform"
        )

        qr = qrcode.QRCode(version=1, box_size=10, border=5)
        qr.add_data(totp_uri)
        qr.make(fit=True)

        img = qr.make_image(fill_color="black", back_color="white")
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        return buffer.getvalue()

    def verify_code(self, user: User, code: str) -> bool:
        """Verify TOTP code"""
        totp = pyotp.TOTP(user.mfa_secret)
        return totp.verify(code, valid_window=1)

    async def generate_backup_codes(self, user: User) -> List[str]:
        """Generate backup codes"""
        codes = [secrets.token_hex(4) for _ in range(10)]
        hashed_codes = [bcrypt.hashpw(c.encode(), bcrypt.gensalt()) for c in codes]
        await self.user_repo.update_backup_codes(user.id, hashed_codes)
        return codes
```

**WebAuthn/FIDO2 Implementation**:
```python
# src/infrastructure/auth/mfa/webauthn_provider.py
from webauthn import (
    generate_registration_options,
    verify_registration_response,
    generate_authentication_options,
    verify_authentication_response
)

class WebAuthnProvider:
    async def start_registration(self, user: User):
        """Start WebAuthn registration"""
        options = generate_registration_options(
            rp_id="platform.com",
            rp_name="Security Platform",
            user_id=str(user.id).encode(),
            user_name=user.email,
            user_display_name=user.full_name
        )

        # Store challenge for verification
        await self.cache.set(
            f"webauthn_challenge:{user.id}",
            options.challenge,
            ttl=300
        )

        return options

    async def complete_registration(self, user: User, credential):
        """Complete WebAuthn registration"""
        challenge = await self.cache.get(f"webauthn_challenge:{user.id}")

        verification = verify_registration_response(
            credential=credential,
            expected_challenge=challenge,
            expected_origin="https://platform.com",
            expected_rp_id="platform.com"
        )

        # Store credential
        await self.user_repo.add_webauthn_credential(
            user.id,
            credential_id=verification.credential_id,
            public_key=verification.credential_public_key
        )
```

**MFA Enforcement**:
```python
# src/domain/models/mfa_policy.py
@dataclass
class MFAPolicy:
    enforce_for_all: bool = False
    enforce_for_roles: List[str] = field(default_factory=list)
    enforce_for_sensitive_actions: bool = True
    allowed_methods: List[str] = field(default_factory=lambda: ['totp', 'sms', 'webauthn'])
    grace_period_days: int = 7

class MFAEnforcer:
    async def require_mfa(self, user: User, action: str):
        """Check if MFA required"""
        policy = await self.get_organization_policy(user.organization_id)

        # Check if user has MFA enabled
        if not user.mfa_enabled:
            if policy.enforce_for_all or user.role in policy.enforce_for_roles:
                grace_period_end = user.created_at + timedelta(days=policy.grace_period_days)
                if datetime.now() > grace_period_end:
                    raise MFARequiredError("MFA enrollment required")

        # Check if action requires MFA
        if action in SENSITIVE_ACTIONS and policy.enforce_for_sensitive_actions:
            if not await self.verify_recent_mfa(user):
                raise MFAVerificationRequired("Please verify with MFA")
```

**Estimated Time**: 18 hours

**Dependencies**: None

---

#### Task 9.13: LDAP Integration

**Story**: As an enterprise admin, I need LDAP integration so that we can use our Active Directory for user authentication.

**Acceptance Criteria**:
- [ ] LDAP connection configuration
- [ ] User authentication against LDAP
- [ ] Group synchronization from LDAP
- [ ] Attribute mapping configuration
- [ ] Connection pooling and failover
- [ ] Secure LDAP (LDAPS) support
- [ ] Periodic user sync
- [ ] Tests for LDAP integration

**LDAP Integration**:
```python
# src/infrastructure/auth/ldap_provider.py
import ldap3
from ldap3 import Server, Connection, ALL, NTLM

class LDAPAuthProvider:
    def __init__(self, organization: Organization):
        self.config = organization.ldap_config
        self.server = Server(
            self.config.host,
            port=self.config.port,
            use_ssl=self.config.use_ssl,
            get_info=ALL
        )

    async def authenticate(self, username: str, password: str) -> User:
        """Authenticate user against LDAP"""
        # Bind with user credentials
        user_dn = f"{self.config.user_dn_template.format(username=username)}"

        conn = Connection(
            self.server,
            user=user_dn,
            password=password,
            authentication=NTLM if self.config.use_ntlm else None
        )

        if not conn.bind():
            raise AuthenticationError("Invalid credentials")

        # Fetch user attributes
        conn.search(
            search_base=self.config.base_dn,
            search_filter=f"(sAMAccountName={username})",
            attributes=['mail', 'givenName', 'sn', 'memberOf']
        )

        if not conn.entries:
            raise UserNotFoundError(f"User {username} not found in LDAP")

        entry = conn.entries[0]

        # Provision or update user
        user = await self.provision_user(
            username=username,
            email=entry.mail.value,
            first_name=entry.givenName.value,
            last_name=entry.sn.value,
            groups=entry.memberOf.values
        )

        conn.unbind()
        return user

    async def sync_users(self):
        """Sync all users from LDAP"""
        conn = Connection(
            self.server,
            user=self.config.bind_dn,
            password=self.config.bind_password
        )

        if not conn.bind():
            raise LDAPConnectionError("Failed to bind to LDAP server")

        # Search for all users
        conn.search(
            search_base=self.config.base_dn,
            search_filter=self.config.user_filter,
            attributes=['sAMAccountName', 'mail', 'givenName', 'sn', 'memberOf']
        )

        for entry in conn.entries:
            try:
                await self.provision_user(
                    username=entry.sAMAccountName.value,
                    email=entry.mail.value,
                    first_name=entry.givenName.value,
                    last_name=entry.sn.value,
                    groups=entry.memberOf.values
                )
            except Exception as e:
                logger.error(f"Failed to sync user {entry.sAMAccountName}: {e}")

        conn.unbind()

    async def sync_groups(self, user: User, ldap_groups: List[str]):
        """Sync user group memberships"""
        # Map LDAP groups to platform roles
        platform_groups = []
        for ldap_group in ldap_groups:
            mapped_group = self.config.group_mapping.get(ldap_group)
            if mapped_group:
                platform_groups.append(mapped_group)

        # Update user groups
        await self.user_repo.update_groups(user.id, platform_groups)
```

**LDAP Configuration**:
```python
# src/domain/models/ldap_config.py
@dataclass
class LDAPConfig:
    host: str
    port: int = 389
    use_ssl: bool = True
    use_ntlm: bool = False
    base_dn: str = ""
    bind_dn: str = ""
    bind_password: str = ""
    user_dn_template: str = "CN={username},OU=Users,DC=example,DC=com"
    user_filter: str = "(objectClass=user)"
    group_mapping: Dict[str, str] = field(default_factory=dict)
    sync_interval_hours: int = 24
```

**Estimated Time**: 16 hours

**Dependencies**: None

---

#### Task 9.14: Session Management

**Story**: As a security engineer, I need advanced session management so that we can control and monitor user sessions.

**Acceptance Criteria**:
- [ ] Session storage in Redis
- [ ] Concurrent session limits per user
- [ ] Session activity tracking
- [ ] IP address validation
- [ ] User-agent validation
- [ ] Session revocation API
- [ ] Admin session management UI
- [ ] Tests for session management

**Session Management**:
```python
# src/infrastructure/auth/session_manager.py
class SessionManager:
    def __init__(self, redis_client, max_sessions: int = 5):
        self.redis = redis_client
        self.max_sessions = max_sessions

    async def create_session(
        self,
        user: User,
        ip_address: str,
        user_agent: str
    ) -> str:
        """Create new session"""
        # Check concurrent session limit
        active_sessions = await self.get_active_sessions(user.id)
        if len(active_sessions) >= self.max_sessions:
            # Revoke oldest session
            oldest = min(active_sessions, key=lambda s: s['created_at'])
            await self.revoke_session(oldest['session_id'])

        # Create session
        session_id = secrets.token_urlsafe(32)
        session_data = {
            'session_id': session_id,
            'user_id': str(user.id),
            'ip_address': ip_address,
            'user_agent': user_agent,
            'created_at': datetime.now().isoformat(),
            'last_activity': datetime.now().isoformat()
        }

        # Store in Redis
        await self.redis.setex(
            f"session:{session_id}",
            timedelta(hours=24),
            json.dumps(session_data)
        )

        # Add to user's session list
        await self.redis.sadd(
            f"user_sessions:{user.id}",
            session_id
        )

        return session_id

    async def validate_session(
        self,
        session_id: str,
        ip_address: str,
        user_agent: str
    ) -> Optional[User]:
        """Validate session and return user"""
        session_data = await self.redis.get(f"session:{session_id}")
        if not session_data:
            return None

        session = json.loads(session_data)

        # Validate IP address (optional, configurable)
        if session['ip_address'] != ip_address:
            logger.warning(
                f"IP address mismatch for session {session_id}: "
                f"{session['ip_address']} vs {ip_address}"
            )
            # Could enforce or just log depending on policy

        # Update last activity
        session['last_activity'] = datetime.now().isoformat()
        await self.redis.setex(
            f"session:{session_id}",
            timedelta(hours=24),
            json.dumps(session)
        )

        # Get user
        user = await self.user_repo.get(UUID(session['user_id']))
        return user

    async def revoke_session(self, session_id: str):
        """Revoke specific session"""
        session_data = await self.redis.get(f"session:{session_id}")
        if session_data:
            session = json.loads(session_data)
            user_id = session['user_id']

            # Remove from Redis
            await self.redis.delete(f"session:{session_id}")
            await self.redis.srem(f"user_sessions:{user_id}", session_id)

    async def revoke_all_user_sessions(self, user_id: UUID):
        """Revoke all sessions for user"""
        session_ids = await self.redis.smembers(f"user_sessions:{user_id}")
        for session_id in session_ids:
            await self.revoke_session(session_id)

    async def get_active_sessions(self, user_id: UUID) -> List[dict]:
        """Get all active sessions for user"""
        session_ids = await self.redis.smembers(f"user_sessions:{user_id}")
        sessions = []
        for session_id in session_ids:
            session_data = await self.redis.get(f"session:{session_id}")
            if session_data:
                sessions.append(json.loads(session_data))
        return sessions
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 9.15: IP Allowlisting & Geo-Restrictions

**Story**: As a security admin, I need IP allowlisting and geo-restrictions so that we can control access to the platform.

**Acceptance Criteria**:
- [ ] Organization-level IP allowlist configuration
- [ ] IP range support (CIDR notation)
- [ ] Geo-location detection from IP
- [ ] Country-based access restrictions
- [ ] Bypass for specific users/roles
- [ ] Access denial logging
- [ ] UI for allowlist management
- [ ] Tests for access control

**IP Access Control**:
```python
# src/infrastructure/security/ip_access_control.py
from ipaddress import ip_address, ip_network
import geoip2.database

class IPAccessControl:
    def __init__(self, geoip_db_path: str):
        self.geoip_reader = geoip2.database.Reader(geoip_db_path)

    async def check_ip_allowed(
        self,
        organization: Organization,
        ip_addr: str
    ) -> bool:
        """Check if IP is allowed for organization"""
        if not organization.ip_allowlist_enabled:
            return True

        # Check if IP in allowlist
        ip = ip_address(ip_addr)
        for allowed_range in organization.ip_allowlist:
            network = ip_network(allowed_range)
            if ip in network:
                return True

        return False

    async def check_geo_restrictions(
        self,
        organization: Organization,
        ip_addr: str
    ) -> bool:
        """Check if IP's country is allowed"""
        if not organization.geo_restrictions_enabled:
            return True

        try:
            response = self.geoip_reader.country(ip_addr)
            country_code = response.country.iso_code

            # Check if country in allowed list
            if organization.geo_restriction_mode == 'allowlist':
                return country_code in organization.allowed_countries
            else:  # blocklist
                return country_code not in organization.blocked_countries
        except geoip2.errors.AddressNotFoundError:
            # Unknown location, default to allowed
            return True

    async def validate_access(
        self,
        user: User,
        ip_addr: str
    ) -> Tuple[bool, Optional[str]]:
        """Validate if user can access from IP"""
        org = await self.org_repo.get(user.organization_id)

        # Bypass for admin users (configurable)
        if user.role == 'admin' and org.allow_admin_bypass:
            return True, None

        # Check IP allowlist
        if not await self.check_ip_allowed(org, ip_addr):
            logger.warning(
                f"Access denied for user {user.id} from IP {ip_addr}: "
                "IP not in allowlist"
            )
            return False, "IP address not allowed"

        # Check geo restrictions
        if not await self.check_geo_restrictions(org, ip_addr):
            response = self.geoip_reader.country(ip_addr)
            logger.warning(
                f"Access denied for user {user.id} from {response.country.name}: "
                "Country restricted"
            )
            return False, f"Access from {response.country.name} is restricted"

        return True, None

# Middleware integration
class IPAccessMiddleware:
    async def __call__(self, request: Request, call_next):
        user = get_current_user()
        if user:
            ip_address = request.client.host
            allowed, reason = await ip_access_control.validate_access(user, ip_address)

            if not allowed:
                raise HTTPException(status_code=403, detail=reason)

        return await call_next(request)
```

**Configuration Model**:
```python
# src/domain/models/access_control_config.py
@dataclass
class AccessControlConfig:
    ip_allowlist_enabled: bool = False
    ip_allowlist: List[str] = field(default_factory=list)  # CIDR notation
    geo_restrictions_enabled: bool = False
    geo_restriction_mode: str = 'allowlist'  # 'allowlist' or 'blocklist'
    allowed_countries: List[str] = field(default_factory=list)  # ISO codes
    blocked_countries: List[str] = field(default_factory=list)
    allow_admin_bypass: bool = True
```

**Estimated Time**: 10 hours

**Dependencies**: None

---

## Epic 4: Administration & Governance

### Epic Goal
Build comprehensive administrative controls and governance systems.

### Tasks

#### Task 9.16: Organization Administration Interface

**Story**: As an organization admin, I need a comprehensive admin interface so that I can manage all aspects of our account.

**Acceptance Criteria**:
- [ ] Organization settings management
- [ ] User management (invite, disable, delete)
- [ ] Role and permission management
- [ ] Subscription and billing management
- [ ] Usage statistics and quotas
- [ ] Audit log viewer
- [ ] API key management
- [ ] Tests for admin operations

**Admin Interface Components**:
```typescript
// src/pages/admin/OrganizationSettings.tsx
interface OrganizationSettingsProps {
  organization: Organization;
  onUpdate: (settings: Partial<Organization>) => Promise<void>;
}

const OrganizationSettings: React.FC<OrganizationSettingsProps> = ({
  organization,
  onUpdate
}) => {
  const [settings, setSettings] = useState(organization);

  const sections = [
    {
      title: 'General',
      component: <GeneralSettings settings={settings} onChange={setSettings} />
    },
    {
      title: 'Authentication',
      component: <AuthenticationSettings settings={settings} onChange={setSettings} />
    },
    {
      title: 'Security',
      component: <SecuritySettings settings={settings} onChange={setSettings} />
    },
    {
      title: 'Integrations',
      component: <IntegrationSettings settings={settings} onChange={setSettings} />
    },
    {
      title: 'Billing',
      component: <BillingSettings settings={settings} onChange={setSettings} />
    }
  ];

  return (
    <AdminLayout>
      <Tabs sections={sections} />
    </AdminLayout>
  );
};
```

**User Management**:
```python
# src/application/services/admin_service.py
class OrganizationAdminService:
    async def invite_user(
        self,
        admin: User,
        email: str,
        role: str,
        teams: List[UUID]
    ) -> UserInvitation:
        """Invite user to organization"""
        # Verify admin permissions
        if not await self.can_invite_users(admin):
            raise PermissionDeniedError("Cannot invite users")

        # Create invitation
        invitation = UserInvitation(
            organization_id=admin.organization_id,
            email=email,
            role=role,
            invited_by=admin.id,
            token=secrets.token_urlsafe(32),
            expires_at=datetime.now() + timedelta(days=7)
        )

        await self.invitation_repo.create(invitation)

        # Send invitation email
        await self.email_service.send_invitation_email(invitation)

        return invitation

    async def disable_user(self, admin: User, user_id: UUID):
        """Disable user account"""
        if not await self.can_manage_users(admin):
            raise PermissionDeniedError("Cannot manage users")

        user = await self.user_repo.get(user_id)

        # Cannot disable self
        if user.id == admin.id:
            raise ValidationError("Cannot disable your own account")

        # Disable user
        user.disabled = True
        await self.user_repo.update(user)

        # Revoke all sessions
        await self.session_manager.revoke_all_user_sessions(user_id)

        # Log action
        await self.audit_log.record(
            action='user_disabled',
            actor_id=admin.id,
            target_id=user_id
        )
```

**Estimated Time**: 20 hours

**Dependencies**: None

---

#### Task 9.17: Granular Permission System

**Story**: As an organization admin, I need granular permissions so that I can control exactly what each user can do.

**Acceptance Criteria**:
- [ ] Resource-based permission model
- [ ] Permission inheritance from roles
- [ ] Custom permission assignments
- [ ] Permission checking middleware
- [ ] Permission caching for performance
- [ ] UI for permission management
- [ ] Permission audit logging
- [ ] Tests for all permission scenarios

**Permission System**:
```python
# src/domain/models/permissions.py
from enum import Enum

class Resource(str, Enum):
    FINDING = "finding"
    CONTRACT = "contract"
    TEAM = "team"
    USER = "user"
    ORGANIZATION = "organization"
    INTEGRATION = "integration"

class Action(str, Enum):
    CREATE = "create"
    READ = "read"
    UPDATE = "update"
    DELETE = "delete"
    ASSIGN = "assign"
    APPROVE = "approve"

@dataclass
class Permission:
    resource: Resource
    action: Action
    scope: str = "organization"  # organization, team, own
    conditions: Dict[str, Any] = field(default_factory=dict)

# Role definitions
ROLES = {
    'admin': [
        Permission(Resource.FINDING, Action.CREATE),
        Permission(Resource.FINDING, Action.READ),
        Permission(Resource.FINDING, Action.UPDATE),
        Permission(Resource.FINDING, Action.DELETE),
        Permission(Resource.FINDING, Action.ASSIGN),
        Permission(Resource.USER, Action.CREATE),
        Permission(Resource.USER, Action.READ),
        Permission(Resource.USER, Action.UPDATE),
        Permission(Resource.USER, Action.DELETE),
        Permission(Resource.ORGANIZATION, Action.UPDATE),
    ],
    'analyst': [
        Permission(Resource.FINDING, Action.CREATE),
        Permission(Resource.FINDING, Action.READ),
        Permission(Resource.FINDING, Action.UPDATE, scope='own'),
        Permission(Resource.CONTRACT, Action.CREATE),
        Permission(Resource.CONTRACT, Action.READ),
    ],
    'viewer': [
        Permission(Resource.FINDING, Action.READ),
        Permission(Resource.CONTRACT, Action.READ),
    ]
}

class PermissionChecker:
    def __init__(self, user: User):
        self.user = user
        self.permissions = self._load_permissions()

    def _load_permissions(self) -> List[Permission]:
        """Load all permissions for user"""
        # Base permissions from role
        permissions = ROLES.get(self.user.role, [])

        # Additional custom permissions
        permissions.extend(self.user.custom_permissions)

        return permissions

    async def can(
        self,
        action: Action,
        resource: Resource,
        target: Optional[Any] = None
    ) -> bool:
        """Check if user can perform action on resource"""
        for perm in self.permissions:
            if perm.action == action and perm.resource == resource:
                # Check scope
                if perm.scope == 'organization':
                    return True
                elif perm.scope == 'team' and target:
                    return await self._in_same_team(target)
                elif perm.scope == 'own' and target:
                    return self._is_owner(target)

        return False

    def _is_owner(self, target: Any) -> bool:
        """Check if user owns the resource"""
        return getattr(target, 'user_id', None) == self.user.id

    async def _in_same_team(self, target: Any) -> bool:
        """Check if target is in user's team"""
        user_teams = await self.team_repo.get_user_teams(self.user.id)
        target_teams = await self.team_repo.get_resource_teams(target)
        return bool(set(user_teams) & set(target_teams))

# Decorator for permission checking
def require_permission(action: Action, resource: Resource):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            user = get_current_user()
            checker = PermissionChecker(user)

            # Get target from kwargs if present
            target = kwargs.get('finding') or kwargs.get('contract')

            if not await checker.can(action, resource, target):
                raise PermissionDeniedError(
                    f"User {user.id} cannot {action} {resource}"
                )

            return await func(*args, **kwargs)
        return wrapper
    return decorator

# Usage
@app.delete("/api/v1/findings/{finding_id}")
@require_permission(Action.DELETE, Resource.FINDING)
async def delete_finding(finding_id: UUID):
    """Delete finding (requires permission)"""
    await finding_service.delete(finding_id)
```

**Estimated Time**: 16 hours

**Dependencies**: None

---

#### Task 9.18: User Provisioning Automation

**Story**: As an IT admin, I need automated user provisioning so that user accounts are created and maintained automatically.

**Acceptance Criteria**:
- [ ] SCIM 2.0 protocol support
- [ ] User creation automation
- [ ] User update synchronization
- [ ] User deprovisioning
- [ ] Group membership sync
- [ ] Attribute mapping configuration
- [ ] Provisioning audit logs
- [ ] Tests for SCIM endpoints

**SCIM Implementation**:
```python
# src/infrastructure/provisioning/scim_provider.py
from scim2_models import User as SCIMUser, Group as SCIMGroup

class SCIMProvider:
    async def create_user(self, scim_user: SCIMUser) -> SCIMUser:
        """Create user via SCIM"""
        user = await self.user_repo.create(User(
            email=scim_user.userName,
            first_name=scim_user.name.givenName,
            last_name=scim_user.name.familyName,
            active=scim_user.active,
            external_id=scim_user.externalId
        ))

        return self._to_scim_user(user)

    async def update_user(self, user_id: str, scim_user: SCIMUser) -> SCIMUser:
        """Update user via SCIM"""
        user = await self.user_repo.get_by_external_id(user_id)

        user.email = scim_user.userName
        user.first_name = scim_user.name.givenName
        user.last_name = scim_user.name.familyName
        user.active = scim_user.active

        await self.user_repo.update(user)

        return self._to_scim_user(user)

    async def delete_user(self, user_id: str):
        """Deprovision user via SCIM"""
        user = await self.user_repo.get_by_external_id(user_id)

        # Soft delete
        user.active = False
        user.deleted_at = datetime.now()
        await self.user_repo.update(user)

        # Revoke sessions
        await self.session_manager.revoke_all_user_sessions(user.id)

    async def get_users(self, filters: dict) -> List[SCIMUser]:
        """List users via SCIM"""
        users = await self.user_repo.find(filters)
        return [self._to_scim_user(u) for u in users]

    def _to_scim_user(self, user: User) -> SCIMUser:
        """Convert internal user to SCIM format"""
        return SCIMUser(
            id=str(user.id),
            userName=user.email,
            name={
                "givenName": user.first_name,
                "familyName": user.last_name
            },
            active=user.active and not user.deleted_at,
            externalId=user.external_id,
            emails=[{"value": user.email, "primary": True}]
        )

# SCIM API endpoints
@app.post("/scim/v2/Users")
async def scim_create_user(scim_user: SCIMUser):
    """SCIM create user endpoint"""
    return await scim_provider.create_user(scim_user)

@app.get("/scim/v2/Users")
async def scim_list_users(filter: str = None):
    """SCIM list users endpoint"""
    filters = parse_scim_filter(filter) if filter else {}
    return await scim_provider.get_users(filters)

@app.put("/scim/v2/Users/{user_id}")
async def scim_update_user(user_id: str, scim_user: SCIMUser):
    """SCIM update user endpoint"""
    return await scim_provider.update_user(user_id, scim_user)

@app.delete("/scim/v2/Users/{user_id}")
async def scim_delete_user(user_id: str):
    """SCIM delete user endpoint"""
    await scim_provider.delete_user(user_id)
    return {"status": "deleted"}
```

**Estimated Time**: 14 hours

**Dependencies**: None

---

#### Task 9.19: Administrative Audit Trail

**Story**: As a compliance officer, I need comprehensive audit trails of all administrative actions so that we can demonstrate accountability.

**Acceptance Criteria**:
- [ ] Audit log database schema
- [ ] All admin actions logged automatically
- [ ] Search and filter capabilities
- [ ] Export to CSV/JSON
- [ ] Retention policy configuration
- [ ] Tamper-evident logging
- [ ] UI for audit log viewing
- [ ] Tests for audit logging

**Audit Trail**:
```python
# src/infrastructure/audit/audit_logger.py
class AuditLogger:
    async def record(
        self,
        action: str,
        actor_id: UUID,
        target_type: str,
        target_id: Optional[UUID] = None,
        details: Optional[Dict] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None
    ):
        """Record audit event"""
        event = AuditEvent(
            action=action,
            actor_id=actor_id,
            target_type=target_type,
            target_id=target_id,
            details=details or {},
            ip_address=ip_address,
            user_agent=user_agent,
            timestamp=datetime.now(),
            checksum=self._calculate_checksum(action, actor_id, target_id)
        )

        await self.audit_repo.create(event)

        # Also log to external service for tamper-evidence
        await self.external_audit_service.log(event)

# Decorator for automatic audit logging
def audit_log(action: str, target_type: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            user = get_current_user()
            request = get_current_request()

            # Execute function
            result = await func(*args, **kwargs)

            # Log action
            target_id = kwargs.get('id') or (result.id if hasattr(result, 'id') else None)
            await audit_logger.record(
                action=action,
                actor_id=user.id,
                target_type=target_type,
                target_id=target_id,
                details=kwargs,
                ip_address=request.client.host,
                user_agent=request.headers.get('user-agent')
            )

            return result
        return wrapper
    return decorator

# Usage
@app.delete("/api/v1/users/{user_id}")
@audit_log("user_deleted", "user")
async def delete_user(user_id: UUID):
    """Delete user (automatically audited)"""
    await user_service.delete(user_id)
```

**Database Schema**:
```sql
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action VARCHAR(100) NOT NULL,
    actor_id UUID NOT NULL REFERENCES users(id),
    target_type VARCHAR(50) NOT NULL,
    target_id UUID,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    checksum VARCHAR(64) NOT NULL,
    INDEX idx_audit_actor (actor_id),
    INDEX idx_audit_target (target_type, target_id),
    INDEX idx_audit_action (action),
    INDEX idx_audit_timestamp (timestamp DESC)
);
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 9.20: Emergency Access Procedures

**Story**: As a security admin, I need emergency access procedures so that we can recover from admin lockouts.

**Acceptance Criteria**:
- [ ] Break-glass account configuration
- [ ] Emergency access request workflow
- [ ] Time-limited emergency access
- [ ] Multi-approval for emergency access
- [ ] Comprehensive logging of emergency access
- [ ] Automatic expiration of emergency sessions
- [ ] Notification of all admins
- [ ] Tests for emergency procedures

**Emergency Access**:
```python
# src/infrastructure/auth/emergency_access.py
class EmergencyAccessManager:
    async def request_emergency_access(
        self,
        requester: User,
        reason: str,
        duration_hours: int = 1
    ) -> EmergencyAccessRequest:
        """Request emergency access"""
        request = EmergencyAccessRequest(
            requester_id=requester.id,
            reason=reason,
            duration_hours=duration_hours,
            status='pending',
            created_at=datetime.now()
        )

        await self.emergency_repo.create(request)

        # Notify all admins for approval
        admins = await self.user_repo.get_organization_admins(
            requester.organization_id
        )
        for admin in admins:
            await self.notification_service.send_emergency_access_request(
                admin, request
            )

        return request

    async def approve_emergency_access(
        self,
        request_id: UUID,
        approver: User
    ):
        """Approve emergency access request"""
        request = await self.emergency_repo.get(request_id)

        # Record approval
        await self.emergency_repo.add_approval(request_id, approver.id)

        # Check if enough approvals (requires 2)
        approvals = await self.emergency_repo.get_approvals(request_id)
        if len(approvals) >= 2:
            # Grant emergency access
            await self.grant_emergency_access(request)

    async def grant_emergency_access(
        self,
        request: EmergencyAccessRequest
    ):
        """Grant emergency access"""
        # Create time-limited admin session
        session = await self.session_manager.create_session(
            user_id=request.requester_id,
            role='emergency_admin',
            expires_at=datetime.now() + timedelta(hours=request.duration_hours)
        )

        # Update request status
        request.status = 'granted'
        request.granted_at = datetime.now()
        await self.emergency_repo.update(request)

        # Log emergency access
        await self.audit_logger.record(
            action='emergency_access_granted',
            actor_id=request.requester_id,
            target_type='organization',
            details={'reason': request.reason, 'duration': request.duration_hours}
        )

        # Notify all admins
        await self.notification_service.broadcast_emergency_access_granted(request)
```

**Estimated Time**: 10 hours

**Dependencies**: Task 9.19

---

## Sprint Backlog

### Week 1: Performance & Scalability

**Monday-Tuesday**: Auto-Scaling & Database
- Task 9.1: Advanced HPA (12h)
- Task 9.2: Database connection pooling (14h)

**Wednesday-Thursday**: Caching & Optimization
- Task 9.3: Multi-tier caching (16h)
- Task 9.4: Database query optimization (14h)

**Friday**: CDN & Load Testing
- Task 9.5: CloudFront CDN optimization (10h)
- Task 9.6: Comprehensive load testing suite (16h - start)

### Week 2: Reliability & Enterprise Auth

**Monday**: Reliability Engineering
- Task 9.6: Load testing (continued)
- Task 9.7: Circuit breakers (12h)
- Task 9.8: Graceful degradation (14h)

**Tuesday-Wednesday**: Rate Limiting & Scaling
- Task 9.9: Dynamic rate limiting (12h)
- Task 9.10: Predictive scaling (16h)

**Thursday-Friday**: Enterprise Authentication
- Task 9.11: SAML 2.0 integration (20h)
- Task 9.12: Multi-factor authentication (18h)

### Week 2 (Continued): LDAP & Session Management

**Weekend/Overlap**:
- Task 9.13: LDAP integration (16h)
- Task 9.14: Session management (12h)
- Task 9.15: IP allowlisting & geo-restrictions (10h)

### Week 2: Administration & Governance

**Throughout**:
- Task 9.16: Organization admin interface (20h)
- Task 9.17: Granular permission system (16h)
- Task 9.18: User provisioning automation (14h)
- Task 9.19: Administrative audit trail (12h)
- Task 9.20: Emergency access procedures (10h)

**Total Estimated Hours**: 314 hours (Team of 6 engineers x 2 weeks = 480 hours available)

---

## Acceptance Criteria Summary

### Performance Optimization
- [x] Platform handles 1000+ concurrent users without degradation
- [x] API response times <100ms at P95 under load
- [x] Auto-scaling responds within 30 seconds of load changes
- [x] Database query performance optimized with proper indexing
- [x] Multi-tier caching reduces database load by >60%
- [x] CDN delivers static assets globally with <100ms latency

### Scalability & Reliability
- [x] Load testing validates 2000+ concurrent user capacity
- [x] Circuit breakers prevent cascade failures
- [x] Graceful degradation maintains core functionality during outages
- [x] Rate limiting prevents abuse while allowing legitimate usage
- [x] Predictive scaling reduces scaling lag

### Enterprise Authentication
- [x] SAML SSO working with Okta, Azure AD, OneLogin
- [x] MFA available via TOTP, SMS, and WebAuthn/FIDO2
- [x] LDAP integration syncs users and groups automatically
- [x] Session management limits concurrent sessions per user
- [x] IP allowlisting and geo-restrictions enforceable per organization

### Administration & Governance
- [x] Organization admins can manage all aspects of their account
- [x] Granular permission system provides resource-based access control
- [x] User provisioning automated via SCIM 2.0
- [x] Administrative actions comprehensively audited
- [x] Emergency access procedures tested and documented

---

## Risks & Mitigation

### Risk 1: Performance Regression
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Comprehensive load testing before each deployment
- Performance monitoring with automated alerts
- Gradual rollout with performance validation
- Rollback procedures tested and documented

### Risk 2: Authentication Integration Complexity
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Early testing with customer identity providers
- Comprehensive documentation and setup guides
- Fallback to password authentication if SSO fails
- Dedicated support for enterprise customers

### Risk 3: Cache Consistency Issues
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Cache invalidation on all data mutations
- TTL configuration based on data volatility
- Cache consistency monitoring
- Ability to flush cache if issues arise

### Risk 4: Scaling Cost Overruns
**Impact**: Medium
**Probability**: Low
**Mitigation**:
- Maximum replica limits configured
- Cost monitoring and alerting
- Predictive scaling to avoid reactive spikes
- Regular review of scaling policies

---

## Success Metrics

### Performance Metrics
- API latency P95: <100ms
- API latency P99: <200ms
- Database query time P95: <20ms
- Cache hit rate: >80%
- CDN offload rate: >90% of static assets
- Auto-scaling response time: <30s

### Scalability Metrics
- Concurrent users supported: >1000
- Peak requests per second: >10,000
- Database connections utilized: <70% of max
- Error rate under load: <0.1%
- Horizontal scaling factor: 10x baseline

### Authentication Metrics
- SAML SSO success rate: >99%
- MFA adoption rate: >60% within 3 months
- Session validation latency: <10ms
- Authentication error rate: <0.5%

### Business Metrics
- Enterprise customer adoption: +25%
- Performance-related support tickets: -50%
- Platform availability: >99.9%
- Customer satisfaction: >4.5/5
- Time to value for enterprise customers: <1 week

---

## Documentation

### Implementation References
- Performance Optimization: `/Users/pwner/Git/ABS/docs/architecture/performance-optimization.md`
- Auto-Scaling Strategy: `/Users/pwner/Git/ABS/docs/infrastructure/auto-scaling.md`
- Caching Architecture: `/Users/pwner/Git/ABS/docs/architecture/caching-strategy.md`
- Enterprise Auth: `/Users/pwner/Git/ABS/docs/features/enterprise-authentication.md`

### API Documentation
- Performance APIs: `/Users/pwner/Git/ABS/docs/api/performance-metrics.md`
- Admin APIs: `/Users/pwner/Git/ABS/docs/api/admin-endpoints.md`
- SCIM API: `/Users/pwner/Git/ABS/docs/api/scim-provisioning.md`

### Administrator Guides
- SAML Configuration: `/Users/pwner/Git/ABS/docs/admin-guides/saml-setup.md`
- LDAP Integration: `/Users/pwner/Git/ABS/docs/admin-guides/ldap-setup.md`
- Permission Management: `/Users/pwner/Git/ABS/docs/admin-guides/permissions.md`
- Emergency Procedures: `/Users/pwner/Git/ABS/docs/admin-guides/emergency-access.md`

### Operational Documentation
- Load Testing Procedures: `/Users/pwner/Git/ABS/docs/operations/load-testing.md`
- Scaling Runbook: `/Users/pwner/Git/ABS/docs/operations/scaling-runbook.md`
- Performance Troubleshooting: `/Users/pwner/Git/ABS/docs/operations/performance-troubleshooting.md`

---

## Dependencies

### External Services
- Identity providers (Okta, Azure AD, OneLogin) for SAML
- LDAP/Active Directory for enterprise auth
- GeoIP database for geo-restrictions
- External audit logging service

### Infrastructure
- Redis for caching and sessions
- CloudFront CDN
- PostgreSQL with read replicas
- Prometheus for custom metrics
- Kubernetes HPA and VPA

### Internal Systems
- Monitoring and alerting infrastructure
- Session management service
- Audit logging service
- Notification service

---

## Future Enhancements (Post-Sprint 9)

### Sprint 10+
- Advanced caching strategies (predictive cache warming)
- Machine learning-based anomaly detection
- Advanced threat protection (DDoS, bot detection)
- Regional data residency
- Advanced compliance reporting
- Custom authentication plugins
- Federated identity management
- Advanced session analytics
- Risk-based authentication
- Passwordless authentication

---

**Sprint 9 Team**: Backend (3), Frontend (1), DevOps (2), Security Engineer (1), QA (1)
**Sprint Goal**: Achieve enterprise-scale performance and security with production-ready authentication and governance
**Definition of Done**: All performance targets met, enterprise authentication functional, load testing passed, admin governance complete, production deployment successful
