# Task 3.8: Performance Optimization

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 4 hours
**Owner**: Backend Team
**Priority**: P1 (High)
**Repository**: All backend services

## Overview

Implement comprehensive performance optimizations across all backend services to achieve sub-100ms API response times for 95th percentile, optimize database queries for sub-50ms execution, implement intelligent caching strategies for 3x+ performance improvement, and ensure efficient resource utilization within Kubernetes limits while maintaining local-first development principles.

## Technical Requirements

### Technology Stack
```yaml
Database Optimization: PostgreSQL query optimization with proper indexing
Caching Strategy: Redis 7.2 with intelligent invalidation and clustering
Connection Pooling: asyncpg with optimized settings for high concurrency
Application Optimization: Async request handling and response compression
Monitoring: Prometheus metrics with performance tracking and alerting
Load Balancing: Kubernetes-native load balancing with health checks
Resource Management: CPU and memory optimization within container limits
```

### Performance Targets
- **API Response Times**: Sub-100ms for 95th percentile across all endpoints
- **Database Queries**: Sub-50ms execution time for standard operations
- **Cache Performance**: 3x+ performance improvement for read operations
- **Memory Usage**: Optimal utilization within Kubernetes resource limits
- **Connection Pooling**: Efficient handling of 500+ concurrent connections
- **Throughput**: 1000+ requests per second per service instance

## Database Performance Optimization

### Query Optimization and Indexing
```sql
-- Optimized indexes for frequent query patterns
-- users table optimization
CREATE INDEX CONCURRENTLY idx_users_email_active
ON users(email) WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_users_roles_gin
ON users USING gin(roles) WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_users_created_at_desc
ON users(created_at DESC) WHERE is_active = true;

-- projects table optimization
CREATE INDEX CONCURRENTLY idx_projects_owner_active
ON projects(owner_id, is_active) WHERE is_active = true;

CREATE INDEX CONCURRENTLY idx_projects_search_gin
ON projects USING gin(to_tsvector('english', name || ' ' || COALESCE(description, '')));

CREATE INDEX CONCURRENTLY idx_projects_created_desc
ON projects(owner_id, created_at DESC) WHERE is_active = true;

-- analyses table optimization
CREATE INDEX CONCURRENTLY idx_analyses_project_status_created
ON analyses(project_id, status, created_at DESC);

CREATE INDEX CONCURRENTLY idx_analyses_status_priority
ON analyses(status, priority DESC, created_at DESC);

-- findings table optimization
CREATE INDEX CONCURRENTLY idx_findings_analysis_severity
ON findings(analysis_id, severity, created_at DESC);

CREATE INDEX CONCURRENTLY idx_findings_search_content
ON findings USING gin(to_tsvector('english', title || ' ' || COALESCE(description, '')));

CREATE INDEX CONCURRENTLY idx_findings_tool_severity
ON findings(tool_source, severity, status);

-- Composite indexes for complex queries
CREATE INDEX CONCURRENTLY idx_findings_project_composite
ON findings(analysis_id)
INCLUDE (severity, status, tool_source, created_at)
WHERE status IN ('open', 'confirmed');

-- Partial indexes for specific use cases
CREATE INDEX CONCURRENTLY idx_findings_critical_open
ON findings(analysis_id, created_at DESC)
WHERE severity = 'critical' AND status = 'open';
```

### Query Performance Monitoring
```python
# shared/database/query_analyzer.py
from sqlalchemy import event, text
from sqlalchemy.engine import Engine
import time
import logging
from typing import Dict, List, Any
from dataclasses import dataclass
from collections import defaultdict
import statistics

@dataclass
class QueryPerformanceMetrics:
    query_hash: str
    avg_duration: float
    max_duration: float
    min_duration: float
    call_count: int
    total_duration: float
    slow_query_threshold: float = 0.1  # 100ms

class QueryPerformanceAnalyzer:
    def __init__(self):
        self.query_metrics: Dict[str, List[float]] = defaultdict(list)
        self.slow_queries: List[Dict[str, Any]] = []
        self.logger = logging.getLogger(__name__)

    def start_monitoring(self, engine: Engine):
        """Start monitoring database query performance."""
        @event.listens_for(engine, "before_cursor_execute")
        def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            context._query_start_time = time.time()
            context._query_statement = statement

        @event.listens_for(engine, "after_cursor_execute")
        def receive_after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
            total_time = time.time() - context._query_start_time

            # Generate query hash for grouping similar queries
            query_hash = self._normalize_query(statement)
            self.query_metrics[query_hash].append(total_time)

            # Log slow queries
            if total_time > 0.1:  # 100ms threshold
                self.slow_queries.append({
                    'statement': statement,
                    'duration': total_time,
                    'timestamp': time.time(),
                    'parameters': str(parameters) if parameters else None
                })

                self.logger.warning(
                    f"Slow query detected: {total_time:.3f}s - {statement[:200]}..."
                )

    def _normalize_query(self, statement: str) -> str:
        """Normalize SQL statement for grouping similar queries."""
        import re
        # Remove parameter placeholders and normalize whitespace
        normalized = re.sub(r'\$\d+', '?', statement)
        normalized = re.sub(r'\s+', ' ', normalized)
        return hash(normalized.strip().lower())

    def get_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive performance report."""
        report = {
            'total_queries': sum(len(durations) for durations in self.query_metrics.values()),
            'unique_query_patterns': len(self.query_metrics),
            'slow_queries_count': len(self.slow_queries),
            'query_patterns': []
        }

        for query_hash, durations in self.query_metrics.items():
            if durations:
                pattern_stats = {
                    'query_hash': query_hash,
                    'call_count': len(durations),
                    'avg_duration': statistics.mean(durations),
                    'max_duration': max(durations),
                    'min_duration': min(durations),
                    'total_duration': sum(durations),
                    'p95_duration': statistics.quantiles(durations, n=20)[18] if len(durations) > 20 else max(durations)
                }
                report['query_patterns'].append(pattern_stats)

        # Sort by total duration (most impactful queries first)
        report['query_patterns'].sort(key=lambda x: x['total_duration'], reverse=True)

        return report

    def suggest_optimizations(self) -> List[str]:
        """Suggest database optimizations based on query patterns."""
        suggestions = []
        report = self.get_performance_report()

        for pattern in report['query_patterns']:
            if pattern['avg_duration'] > 0.05:  # 50ms average
                suggestions.append(
                    f"Query pattern with hash {pattern['query_hash']} has high average duration "
                    f"({pattern['avg_duration']:.3f}s). Consider adding indexes or optimizing the query."
                )

            if pattern['call_count'] > 1000 and pattern['avg_duration'] > 0.01:  # Frequent but slow
                suggestions.append(
                    f"Frequently called query pattern ({pattern['call_count']} calls) could benefit "
                    f"from caching or better indexing."
                )

        return suggestions
```

### Optimized Repository Patterns
```python
# data-service/src/repositories/optimized_repositories.py
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_, or_
from sqlalchemy.orm import selectinload, joinedload, contains_eager
from typing import List, Optional, Dict, Any
import uuid

class OptimizedUserRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_user_with_projects_optimized(self, user_id: uuid.UUID) -> Optional[UserModel]:
        """Get user with projects using optimized loading."""
        result = await self.session.execute(
            select(UserModel)
            .options(
                selectinload(UserModel.projects).selectinload(ProjectModel.analyses)
            )
            .where(UserModel.id == user_id)
        )
        return result.scalar_one_or_none()

    async def get_users_with_pagination_optimized(
        self,
        page: int = 1,
        page_size: int = 20,
        search_query: Optional[str] = None
    ) -> Dict[str, Any]:
        """Get paginated users with optimized query and search."""
        offset = (page - 1) * page_size

        # Build base query
        query = select(UserModel).where(UserModel.is_active == True)

        # Add search if provided
        if search_query:
            search_filter = or_(
                UserModel.email.ilike(f"%{search_query}%"),
                UserModel.username.ilike(f"%{search_query}%")
            )
            query = query.where(search_filter)

        # Get total count (optimized)
        count_query = select(func.count(UserModel.id)).select_from(query.subquery())
        total_result = await self.session.execute(count_query)
        total_count = total_result.scalar()

        # Get paginated results
        paginated_query = query.offset(offset).limit(page_size).order_by(UserModel.created_at.desc())
        result = await self.session.execute(paginated_query)
        users = list(result.scalars().all())

        return {
            'items': users,
            'total': total_count,
            'page': page,
            'page_size': page_size,
            'total_pages': (total_count + page_size - 1) // page_size
        }

class OptimizedFindingRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_findings_with_analytics(self, project_id: uuid.UUID) -> Dict[str, Any]:
        """Get findings with analytics in a single optimized query."""
        # Get findings with analysis data
        findings_query = (
            select(FindingModel)
            .join(FindingModel.analysis)
            .options(contains_eager(FindingModel.analysis))
            .where(AnalysisModel.project_id == project_id)
            .order_by(FindingModel.severity_weight.desc(), FindingModel.created_at.desc())
        )

        findings_result = await self.session.execute(findings_query)
        findings = list(findings_result.scalars().unique().all())

        # Get analytics in single query
        analytics_query = (
            select(
                FindingModel.severity,
                FindingModel.status,
                FindingModel.tool_source,
                func.count(FindingModel.id).label('count')
            )
            .join(FindingModel.analysis)
            .where(AnalysisModel.project_id == project_id)
            .group_by(FindingModel.severity, FindingModel.status, FindingModel.tool_source)
        )

        analytics_result = await self.session.execute(analytics_query)
        analytics_rows = analytics_result.fetchall()

        # Process analytics
        analytics = {
            'by_severity': defaultdict(int),
            'by_status': defaultdict(int),
            'by_tool': defaultdict(int),
            'total_findings': len(findings)
        }

        for row in analytics_rows:
            analytics['by_severity'][row.severity] += row.count
            analytics['by_status'][row.status] += row.count
            analytics['by_tool'][row.tool_source] += row.count

        return {
            'findings': findings,
            'analytics': analytics
        }

    async def bulk_update_findings_optimized(
        self,
        finding_ids: List[uuid.UUID],
        updates: Dict[str, Any]
    ) -> int:
        """Bulk update findings with optimized query."""
        from sqlalchemy import update

        result = await self.session.execute(
            update(FindingModel)
            .where(FindingModel.id.in_(finding_ids))
            .values(**updates)
        )

        return result.rowcount
```

## Redis Caching Optimization

### Advanced Caching Strategies
```python
# shared/cache/advanced_cache.py
import json
import pickle
import asyncio
from typing import Any, Optional, List, Dict, Callable, Union
from redis.asyncio import Redis, ConnectionPool
from datetime import timedelta
import hashlib
import time
from functools import wraps
import logging

class AdvancedCacheManager:
    def __init__(self, redis_url: str, cluster_mode: bool = False):
        self.logger = logging.getLogger(__name__)

        if cluster_mode:
            from redis.asyncio import RedisCluster
            self.redis = RedisCluster.from_url(redis_url, decode_responses=False)
        else:
            self.pool = ConnectionPool.from_url(
                redis_url,
                max_connections=100,
                retry_on_timeout=True,
                socket_keepalive=True,
                socket_keepalive_options={},
                decode_responses=False
            )
            self.redis = Redis(connection_pool=self.pool)

        # Cache statistics
        self.stats = {
            'hits': 0,
            'misses': 0,
            'sets': 0,
            'deletes': 0
        }

    async def get_with_fallback(
        self,
        key: str,
        fallback_func: Callable,
        ttl: Optional[timedelta] = None,
        cache_empty: bool = False
    ) -> Any:
        """Get from cache with automatic fallback to function if not found."""
        try:
            # Try to get from cache
            cached_value = await self.get(key)
            if cached_value is not None:
                self.stats['hits'] += 1
                return cached_value

            self.stats['misses'] += 1

            # Execute fallback function
            if asyncio.iscoroutinefunction(fallback_func):
                value = await fallback_func()
            else:
                value = fallback_func()

            # Cache the result if it's not empty or we're caching empty values
            if value is not None or cache_empty:
                await self.set(key, value, ttl)

            return value

        except Exception as e:
            self.logger.error(f"Cache operation failed for key {key}: {e}")
            # Fallback to direct function call
            if asyncio.iscoroutinefunction(fallback_func):
                return await fallback_func()
            else:
                return fallback_func()

    async def get(self, key: str, default: Any = None) -> Any:
        """Get value from cache with deserialization."""
        try:
            value = await self.redis.get(key)
            if value is None:
                return default
            return pickle.loads(value)
        except Exception as e:
            self.logger.error(f"Failed to get key {key}: {e}")
            return default

    async def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[Union[int, timedelta]] = None
    ) -> bool:
        """Set value in cache with serialization."""
        try:
            serialized = pickle.dumps(value)

            if ttl:
                if isinstance(ttl, timedelta):
                    ttl_seconds = int(ttl.total_seconds())
                else:
                    ttl_seconds = ttl
                result = await self.redis.setex(key, ttl_seconds, serialized)
            else:
                result = await self.redis.set(key, serialized)

            if result:
                self.stats['sets'] += 1
            return bool(result)

        except Exception as e:
            self.logger.error(f"Failed to set key {key}: {e}")
            return False

    async def mget(self, keys: List[str]) -> List[Any]:
        """Get multiple values from cache."""
        try:
            values = await self.redis.mget(keys)
            return [
                pickle.loads(value) if value is not None else None
                for value in values
            ]
        except Exception as e:
            self.logger.error(f"Failed to mget keys {keys}: {e}")
            return [None] * len(keys)

    async def mset(self, mapping: Dict[str, Any], ttl: Optional[int] = None) -> bool:
        """Set multiple values in cache."""
        try:
            serialized_mapping = {
                key: pickle.dumps(value)
                for key, value in mapping.items()
            }

            if ttl:
                # Use pipeline for atomic operation with TTL
                pipe = self.redis.pipeline()
                pipe.mset(serialized_mapping)
                for key in serialized_mapping.keys():
                    pipe.expire(key, ttl)
                results = await pipe.execute()
                return all(results[:-len(serialized_mapping)])
            else:
                result = await self.redis.mset(serialized_mapping)
                if result:
                    self.stats['sets'] += len(mapping)
                return bool(result)

        except Exception as e:
            self.logger.error(f"Failed to mset: {e}")
            return False

    async def delete_pattern(self, pattern: str) -> int:
        """Delete all keys matching pattern."""
        try:
            keys = await self.redis.keys(pattern)
            if keys:
                deleted = await self.redis.delete(*keys)
                self.stats['deletes'] += deleted
                return deleted
            return 0
        except Exception as e:
            self.logger.error(f"Failed to delete pattern {pattern}: {e}")
            return 0

    async def warm_cache(self, warm_functions: List[Callable]) -> Dict[str, Any]:
        """Pre-warm cache with frequently accessed data."""
        results = {}

        async def warm_single(func):
            try:
                if asyncio.iscoroutinefunction(func):
                    return await func()
                else:
                    return func()
            except Exception as e:
                self.logger.error(f"Cache warming failed for {func.__name__}: {e}")
                return None

        # Execute all warming functions concurrently
        tasks = [warm_single(func) for func in warm_functions]
        warm_results = await asyncio.gather(*tasks, return_exceptions=True)

        for func, result in zip(warm_functions, warm_results):
            results[func.__name__] = {
                'success': not isinstance(result, Exception),
                'result': result if not isinstance(result, Exception) else str(result)
            }

        return results

    def cached_method(
        self,
        ttl: Optional[timedelta] = None,
        key_prefix: str = "",
        include_self: bool = False
    ):
        """Decorator for caching method results."""
        def decorator(func):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                # Generate cache key
                key_parts = [key_prefix, func.__name__]

                if not include_self and args:
                    # Skip 'self' parameter for instance methods
                    cache_args = args[1:]
                else:
                    cache_args = args

                # Add arguments to key
                for arg in cache_args:
                    if hasattr(arg, 'id'):
                        key_parts.append(str(arg.id))
                    elif isinstance(arg, (str, int, float, bool)):
                        key_parts.append(str(arg))

                # Add keyword arguments
                if kwargs:
                    sorted_kwargs = sorted(kwargs.items())
                    key_hash = hashlib.md5(
                        json.dumps(sorted_kwargs, sort_keys=True).encode()
                    ).hexdigest()
                    key_parts.append(key_hash)

                cache_key = ":".join(key_parts)

                # Try cache first
                cached_result = await self.get(cache_key)
                if cached_result is not None:
                    self.stats['hits'] += 1
                    return cached_result

                self.stats['misses'] += 1

                # Execute function
                result = await func(*args, **kwargs)

                # Cache result
                if result is not None:
                    await self.set(cache_key, result, ttl)

                return result

            return wrapper
        return decorator

    async def get_cache_stats(self) -> Dict[str, Any]:
        """Get cache performance statistics."""
        info = await self.redis.info()

        total_requests = self.stats['hits'] + self.stats['misses']
        hit_rate = (self.stats['hits'] / total_requests * 100) if total_requests > 0 else 0

        return {
            'application_stats': {
                'hits': self.stats['hits'],
                'misses': self.stats['misses'],
                'hit_rate_percent': round(hit_rate, 2),
                'sets': self.stats['sets'],
                'deletes': self.stats['deletes']
            },
            'redis_stats': {
                'used_memory': info.get('used_memory_human'),
                'connected_clients': info.get('connected_clients'),
                'total_commands_processed': info.get('total_commands_processed'),
                'keyspace_hits': info.get('keyspace_hits'),
                'keyspace_misses': info.get('keyspace_misses'),
                'redis_hit_rate_percent': round(
                    (info.get('keyspace_hits', 0) /
                     (info.get('keyspace_hits', 0) + info.get('keyspace_misses', 1)) * 100), 2
                )
            }
        }
```

### Smart Caching Service Integration
```python
# shared/cache/smart_cache_service.py
from typing import Any, Optional, List, Dict, Callable
from datetime import timedelta
from .advanced_cache import AdvancedCacheManager

class SmartCacheService:
    def __init__(self, cache_manager: AdvancedCacheManager):
        self.cache = cache_manager

        # TTL configurations for different data types
        self.ttl_config = {
            'user_profile': timedelta(minutes=30),
            'user_permissions': timedelta(minutes=15),
            'project_data': timedelta(minutes=20),
            'analysis_results': timedelta(hours=1),
            'finding_summaries': timedelta(minutes=10),
            'search_results': timedelta(minutes=5),
            'analytics_data': timedelta(minutes=30),
            'configuration': timedelta(hours=2),
            'static_data': timedelta(hours=6)
        }

    async def get_user_data_optimized(self, user_id: str) -> Dict[str, Any]:
        """Get comprehensive user data with optimized caching."""
        cache_key = f"user_complete:{user_id}"

        async def fetch_user_data():
            # This would typically fetch from multiple sources
            from src.repositories.user_repository import UserRepository
            from src.repositories.project_repository import ProjectRepository

            # In a real implementation, these would be injected
            user_repo = get_user_repository()
            project_repo = get_project_repository()

            user = await user_repo.get_by_id(user_id)
            if not user:
                return None

            projects = await project_repo.get_by_owner(user_id)

            return {
                'user': user,
                'projects': projects,
                'project_count': len(projects),
                'last_activity': max([p.updated_at for p in projects] + [user.updated_at])
            }

        return await self.cache.get_with_fallback(
            cache_key,
            fetch_user_data,
            ttl=self.ttl_config['user_profile']
        )

    async def get_project_analytics_cached(self, project_id: str) -> Dict[str, Any]:
        """Get project analytics with intelligent caching."""
        cache_key = f"project_analytics:{project_id}"

        async def fetch_analytics():
            from src.services.analytics_service import AnalyticsService

            analytics_service = get_analytics_service()
            return await analytics_service.get_comprehensive_analytics(project_id)

        return await self.cache.get_with_fallback(
            cache_key,
            fetch_analytics,
            ttl=self.ttl_config['analytics_data']
        )

    async def cache_search_results(
        self,
        search_query: str,
        filters: Dict[str, Any],
        results: List[Any]
    ) -> bool:
        """Cache search results with normalized key."""
        import hashlib
        import json

        # Create normalized cache key
        search_data = {
            'query': search_query.lower().strip(),
            'filters': dict(sorted(filters.items()))
        }

        key_hash = hashlib.md5(
            json.dumps(search_data, sort_keys=True).encode()
        ).hexdigest()

        cache_key = f"search_results:{key_hash}"

        return await self.cache.set(
            cache_key,
            results,
            ttl=self.ttl_config['search_results']
        )

    async def invalidate_user_cache(self, user_id: str):
        """Invalidate all cache entries related to a user."""
        patterns = [
            f"user_complete:{user_id}",
            f"user_*:{user_id}",
            f"project_*:*:{user_id}",  # Projects owned by user
        ]

        for pattern in patterns:
            await self.cache.delete_pattern(pattern)

    async def invalidate_project_cache(self, project_id: str):
        """Invalidate all cache entries related to a project."""
        patterns = [
            f"project_*:{project_id}*",
            f"analysis_*:{project_id}*",
            f"finding_*:{project_id}*",
            f"analytics_*:{project_id}*"
        ]

        for pattern in patterns:
            await self.cache.delete_pattern(pattern)

    async def warm_frequently_accessed_data(self) -> Dict[str, Any]:
        """Warm cache with frequently accessed data."""
        warming_functions = [
            self._warm_active_users,
            self._warm_recent_projects,
            self._warm_critical_findings,
            self._warm_system_configuration
        ]

        return await self.cache.warm_cache(warming_functions)

    async def _warm_active_users(self):
        """Warm cache with active user data."""
        from src.repositories.user_repository import UserRepository

        user_repo = get_user_repository()
        active_users = await user_repo.get_recently_active_users(limit=100)

        # Cache individual user profiles
        tasks = []
        for user in active_users:
            cache_key = f"user_profile:{user.id}"
            tasks.append(
                self.cache.set(cache_key, user, ttl=self.ttl_config['user_profile'])
            )

        await asyncio.gather(*tasks)
        return f"Warmed {len(active_users)} user profiles"

    async def _warm_recent_projects(self):
        """Warm cache with recent project data."""
        from src.repositories.project_repository import ProjectRepository

        project_repo = get_project_repository()
        recent_projects = await project_repo.get_recently_updated(limit=50)

        tasks = []
        for project in recent_projects:
            cache_key = f"project_data:{project.id}"
            tasks.append(
                self.cache.set(cache_key, project, ttl=self.ttl_config['project_data'])
            )

        await asyncio.gather(*tasks)
        return f"Warmed {len(recent_projects)} project profiles"

    async def _warm_critical_findings(self):
        """Warm cache with critical findings."""
        from src.repositories.finding_repository import FindingRepository

        finding_repo = get_finding_repository()
        critical_findings = await finding_repo.get_critical_findings(limit=100)

        # Group by project for efficient caching
        by_project = {}
        for finding in critical_findings:
            project_id = finding.analysis.project_id
            if project_id not in by_project:
                by_project[project_id] = []
            by_project[project_id].append(finding)

        tasks = []
        for project_id, findings in by_project.items():
            cache_key = f"critical_findings:{project_id}"
            tasks.append(
                self.cache.set(cache_key, findings, ttl=self.ttl_config['finding_summaries'])
            )

        await asyncio.gather(*tasks)
        return f"Warmed critical findings for {len(by_project)} projects"

    async def _warm_system_configuration(self):
        """Warm cache with system configuration."""
        from src.services.configuration_service import ConfigurationService

        config_service = get_configuration_service()
        system_config = await config_service.get_system_configuration()

        cache_key = "system_configuration"
        await self.cache.set(
            cache_key,
            system_config,
            ttl=self.ttl_config['configuration']
        )

        return "Warmed system configuration"
```

## Application-Level Performance Optimization

### Async Request Handling Optimization
```python
# shared/performance/async_optimization.py
import asyncio
import time
from typing import List, Callable, Any, Dict
from functools import wraps
import logging
from concurrent.futures import ThreadPoolExecutor

class AsyncPerformanceOptimizer:
    def __init__(self, max_workers: int = 10):
        self.thread_pool = ThreadPoolExecutor(max_workers=max_workers)
        self.logger = logging.getLogger(__name__)

    def async_timed(self, operation_name: str):
        """Decorator to measure async operation performance."""
        def decorator(func):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                start_time = time.time()
                try:
                    result = await func(*args, **kwargs)
                    duration = time.time() - start_time

                    if duration > 0.1:  # Log slow operations
                        self.logger.warning(
                            f"Slow operation {operation_name}: {duration:.3f}s"
                        )

                    return result
                except Exception as e:
                    duration = time.time() - start_time
                    self.logger.error(
                        f"Failed operation {operation_name} after {duration:.3f}s: {e}"
                    )
                    raise
            return wrapper
        return decorator

    async def run_concurrent_limited(
        self,
        operations: List[Callable],
        max_concurrent: int = 5
    ) -> List[Any]:
        """Run operations concurrently with concurrency limit."""
        semaphore = asyncio.Semaphore(max_concurrent)

        async def limited_operation(operation):
            async with semaphore:
                if asyncio.iscoroutinefunction(operation):
                    return await operation()
                else:
                    # Run in thread pool for CPU-bound operations
                    loop = asyncio.get_event_loop()
                    return await loop.run_in_executor(self.thread_pool, operation)

        tasks = [limited_operation(op) for op in operations]
        return await asyncio.gather(*tasks, return_exceptions=True)

    async def batch_process_with_backpressure(
        self,
        items: List[Any],
        processor: Callable,
        batch_size: int = 10,
        max_concurrent_batches: int = 3
    ) -> List[Any]:
        """Process items in batches with backpressure control."""
        results = []

        # Split items into batches
        batches = [
            items[i:i + batch_size]
            for i in range(0, len(items), batch_size)
        ]

        semaphore = asyncio.Semaphore(max_concurrent_batches)

        async def process_batch(batch):
            async with semaphore:
                batch_results = []
                for item in batch:
                    if asyncio.iscoroutinefunction(processor):
                        result = await processor(item)
                    else:
                        loop = asyncio.get_event_loop()
                        result = await loop.run_in_executor(self.thread_pool, processor, item)
                    batch_results.append(result)
                return batch_results

        # Process all batches
        batch_tasks = [process_batch(batch) for batch in batches]
        batch_results = await asyncio.gather(*batch_tasks)

        # Flatten results
        for batch_result in batch_results:
            results.extend(batch_result)

        return results

# API request optimization
# api-service/src/middleware/performance_middleware.py
from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import time
import gzip
import json

class PerformanceMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, compress_response: bool = True, min_size: int = 1000):
        super().__init__(app)
        self.compress_response = compress_response
        self.min_size = min_size

    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        # Add request ID for tracing
        request_id = f"req_{int(time.time() * 1000)}_{id(request)}"
        request.state.request_id = request_id

        response = await call_next(request)

        # Add performance headers
        process_time = time.time() - start_time
        response.headers["X-Process-Time"] = str(process_time)
        response.headers["X-Request-ID"] = request_id

        # Response compression
        if (self.compress_response and
            response.headers.get("content-length") and
            int(response.headers["content-length"]) > self.min_size and
            "gzip" in request.headers.get("accept-encoding", "")):

            response = await self._compress_response(response)

        return response

    async def _compress_response(self, response: Response) -> Response:
        """Compress response body if beneficial."""
        if hasattr(response, 'body'):
            compressed_body = gzip.compress(response.body)

            # Only use compression if it actually reduces size
            if len(compressed_body) < len(response.body):
                response.body = compressed_body
                response.headers["content-encoding"] = "gzip"
                response.headers["content-length"] = str(len(compressed_body))

        return response

# Response optimization
class ResponseOptimizer:
    @staticmethod
    async def paginate_large_response(
        data: List[Any],
        page: int = 1,
        page_size: int = 20,
        max_page_size: int = 100
    ) -> Dict[str, Any]:
        """Optimize large response with pagination."""
        # Limit page size to prevent memory issues
        page_size = min(page_size, max_page_size)

        total_items = len(data)
        start_index = (page - 1) * page_size
        end_index = start_index + page_size

        paginated_data = data[start_index:end_index]

        return {
            'items': paginated_data,
            'pagination': {
                'page': page,
                'page_size': page_size,
                'total_items': total_items,
                'total_pages': (total_items + page_size - 1) // page_size,
                'has_next': end_index < total_items,
                'has_previous': page > 1
            }
        }

    @staticmethod
    def optimize_json_response(data: Any) -> str:
        """Optimize JSON serialization for large responses."""
        return json.dumps(
            data,
            separators=(',', ':'),  # Remove whitespace
            ensure_ascii=False,     # Allow Unicode
            default=str            # Handle non-serializable objects
        )
```

## Connection Pool Optimization

### Database Connection Pool Tuning
```python
# shared/database/optimized_pool.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import QueuePool, StaticPool
from typing import AsyncGenerator, Optional
import os
import logging

class OptimizedDatabaseManager:
    def __init__(self, database_url: str, environment: str = "production"):
        self.database_url = database_url
        self.environment = environment
        self.logger = logging.getLogger(__name__)

        # Environment-specific configurations
        if environment == "production":
            pool_config = {
                "poolclass": QueuePool,
                "pool_size": 20,              # Base connections
                "max_overflow": 30,           # Additional connections under load
                "pool_pre_ping": True,        # Validate connections
                "pool_recycle": 3600,         # Recycle connections every hour
                "pool_timeout": 30,           # Timeout for getting connection
                "echo": False
            }
        elif environment == "development":
            pool_config = {
                "poolclass": QueuePool,
                "pool_size": 5,
                "max_overflow": 10,
                "pool_pre_ping": True,
                "pool_recycle": 1800,
                "pool_timeout": 10,
                "echo": True  # Enable SQL logging in development
            }
        else:  # testing
            pool_config = {
                "poolclass": StaticPool,
                "pool_size": 1,
                "max_overflow": 0,
                "pool_pre_ping": False,
                "echo": False
            }

        self.engine = create_async_engine(database_url, **pool_config)

        self.session_factory = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False,
            autoflush=False  # Manual control over flushing
        )

    async def get_session(self) -> AsyncGenerator[AsyncSession, None]:
        """Get optimized database session with proper resource management."""
        async with self.session_factory() as session:
            try:
                yield session
            except Exception as e:
                await session.rollback()
                self.logger.error(f"Database session error: {e}")
                raise
            finally:
                await session.close()

    async def get_pool_status(self) -> dict:
        """Get connection pool status for monitoring."""
        pool = self.engine.pool

        return {
            "pool_size": pool.size(),
            "connections_checked_in": pool.checkedin(),
            "connections_checked_out": pool.checkedout(),
            "connections_overflow": pool.overflow(),
            "connections_total": pool.size() + pool.overflow(),
            "pool_timeout": getattr(pool, '_timeout', None),
            "pool_recycle": getattr(pool, '_recycle', None)
        }

    async def warm_up_pool(self) -> bool:
        """Warm up connection pool by creating initial connections."""
        try:
            # Create a few connections to warm up the pool
            sessions = []
            for _ in range(min(5, self.engine.pool.size())):
                session = self.session_factory()
                await session.execute(text("SELECT 1"))
                sessions.append(session)

            # Close all sessions
            for session in sessions:
                await session.close()

            self.logger.info("Database connection pool warmed up successfully")
            return True

        except Exception as e:
            self.logger.error(f"Failed to warm up connection pool: {e}")
            return False

    async def close(self):
        """Properly close the database engine and all connections."""
        await self.engine.dispose()
```

## Performance Monitoring and Alerting

### Comprehensive Performance Monitoring
```python
# shared/monitoring/performance_monitor.py
from prometheus_client import Counter, Histogram, Gauge, CollectorRegistry
import time
import psutil
import asyncio
from typing import Dict, Any, List
from datetime import datetime, timedelta

class PerformanceMonitor:
    def __init__(self):
        self.registry = CollectorRegistry()

        # API Performance Metrics
        self.request_duration = Histogram(
            'http_request_duration_seconds',
            'HTTP request duration',
            ['method', 'endpoint', 'status'],
            registry=self.registry
        )

        self.request_count = Counter(
            'http_requests_total',
            'Total HTTP requests',
            ['method', 'endpoint', 'status'],
            registry=self.registry
        )

        # Database Performance Metrics
        self.db_query_duration = Histogram(
            'db_query_duration_seconds',
            'Database query duration',
            ['operation', 'table'],
            registry=self.registry
        )

        self.db_connection_pool = Gauge(
            'db_connections_active',
            'Active database connections',
            registry=self.registry
        )

        # Cache Performance Metrics
        self.cache_operations = Counter(
            'cache_operations_total',
            'Cache operations',
            ['operation', 'result'],
            registry=self.registry
        )

        self.cache_hit_rate = Gauge(
            'cache_hit_rate',
            'Cache hit rate percentage',
            registry=self.registry
        )

        # System Resource Metrics
        self.memory_usage = Gauge(
            'memory_usage_bytes',
            'Memory usage in bytes',
            ['type'],
            registry=self.registry
        )

        self.cpu_usage = Gauge(
            'cpu_usage_percent',
            'CPU usage percentage',
            registry=self.registry
        )

    async def start_monitoring(self):
        """Start background monitoring tasks."""
        asyncio.create_task(self._monitor_system_resources())
        asyncio.create_task(self._monitor_performance_thresholds())

    async def _monitor_system_resources(self):
        """Monitor system resource usage."""
        while True:
            try:
                # Memory monitoring
                memory = psutil.virtual_memory()
                self.memory_usage.labels(type='total').set(memory.total)
                self.memory_usage.labels(type='used').set(memory.used)
                self.memory_usage.labels(type='available').set(memory.available)

                # CPU monitoring
                cpu_percent = psutil.cpu_percent(interval=1)
                self.cpu_usage.set(cpu_percent)

                await asyncio.sleep(30)  # Monitor every 30 seconds

            except Exception as e:
                print(f"Error monitoring system resources: {e}")
                await asyncio.sleep(60)

    async def _monitor_performance_thresholds(self):
        """Monitor performance thresholds and alert if exceeded."""
        while True:
            try:
                # Check API response times
                # This would typically query metrics backend
                avg_response_time = await self._get_avg_response_time()
                if avg_response_time > 0.1:  # 100ms threshold
                    await self._alert_performance_issue(
                        "API response time exceeded threshold",
                        {"avg_response_time": avg_response_time}
                    )

                # Check cache hit rate
                hit_rate = await self._get_cache_hit_rate()
                if hit_rate < 0.8:  # 80% threshold
                    await self._alert_performance_issue(
                        "Cache hit rate below threshold",
                        {"hit_rate": hit_rate}
                    )

                # Check database connection pool
                pool_usage = await self._get_db_pool_usage()
                if pool_usage > 0.9:  # 90% threshold
                    await self._alert_performance_issue(
                        "Database connection pool near capacity",
                        {"pool_usage": pool_usage}
                    )

                await asyncio.sleep(300)  # Check every 5 minutes

            except Exception as e:
                print(f"Error monitoring performance thresholds: {e}")
                await asyncio.sleep(300)

    async def _get_avg_response_time(self) -> float:
        """Get average response time from metrics."""
        # This would typically query Prometheus or another metrics backend
        # For now, return a mock value
        return 0.05

    async def _get_cache_hit_rate(self) -> float:
        """Get cache hit rate from metrics."""
        # Mock implementation
        return 0.85

    async def _get_db_pool_usage(self) -> float:
        """Get database pool usage percentage."""
        # Mock implementation
        return 0.6

    async def _alert_performance_issue(self, message: str, details: Dict[str, Any]):
        """Send performance alert."""
        alert_data = {
            "timestamp": datetime.utcnow().isoformat(),
            "severity": "warning",
            "message": message,
            "details": details,
            "service": "backend-services"
        }

        # This would typically send to alerting system
        print(f"PERFORMANCE ALERT: {alert_data}")

    def track_request_performance(self, method: str, endpoint: str, status: int, duration: float):
        """Track individual request performance."""
        self.request_duration.labels(
            method=method,
            endpoint=endpoint,
            status=str(status)
        ).observe(duration)

        self.request_count.labels(
            method=method,
            endpoint=endpoint,
            status=str(status)
        ).inc()

    def track_db_query_performance(self, operation: str, table: str, duration: float):
        """Track database query performance."""
        self.db_query_duration.labels(
            operation=operation,
            table=table
        ).observe(duration)

    def track_cache_operation(self, operation: str, hit: bool):
        """Track cache operation performance."""
        result = "hit" if hit else "miss"
        self.cache_operations.labels(
            operation=operation,
            result=result
        ).inc()

    async def get_performance_report(self) -> Dict[str, Any]:
        """Generate comprehensive performance report."""
        return {
            "timestamp": datetime.utcnow().isoformat(),
            "api_performance": {
                "avg_response_time": await self._get_avg_response_time(),
                "request_rate": await self._get_request_rate(),
                "error_rate": await self._get_error_rate()
            },
            "database_performance": {
                "avg_query_time": await self._get_avg_query_time(),
                "connection_pool_usage": await self._get_db_pool_usage(),
                "slow_query_count": await self._get_slow_query_count()
            },
            "cache_performance": {
                "hit_rate": await self._get_cache_hit_rate(),
                "memory_usage": await self._get_cache_memory_usage(),
                "operation_rate": await self._get_cache_operation_rate()
            },
            "system_resources": {
                "cpu_usage": psutil.cpu_percent(),
                "memory_usage": psutil.virtual_memory().percent,
                "disk_usage": psutil.disk_usage('/').percent
            }
        }

    async def _get_request_rate(self) -> float:
        """Get current request rate."""
        return 250.0  # Mock value

    async def _get_error_rate(self) -> float:
        """Get current error rate."""
        return 0.01  # Mock value

    async def _get_avg_query_time(self) -> float:
        """Get average database query time."""
        return 0.025  # Mock value

    async def _get_slow_query_count(self) -> int:
        """Get count of slow queries."""
        return 5  # Mock value

    async def _get_cache_memory_usage(self) -> int:
        """Get cache memory usage in bytes."""
        return 1024 * 1024 * 100  # 100MB mock value

    async def _get_cache_operation_rate(self) -> float:
        """Get cache operation rate."""
        return 500.0  # Mock value
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`

## Deliverables

### Performance Optimization Structure
```
shared/performance/
├── database/
│   ├── query_analyzer.py         # Query performance analysis
│   ├── optimized_repositories.py # Optimized repository patterns
│   └── connection_pool.py        # Connection pool optimization
├── cache/
│   ├── advanced_cache.py         # Advanced caching strategies
│   ├── smart_cache_service.py    # Intelligent cache management
│   └── cache_warming.py          # Cache pre-warming utilities
├── async/
│   ├── async_optimization.py     # Async operation optimization
│   ├── concurrency_control.py    # Concurrency management
│   └── batch_processing.py       # Batch processing optimization
├── monitoring/
│   ├── performance_monitor.py    # Performance metrics collection
│   ├── alerting.py              # Performance alerting
│   └── benchmarking.py          # Performance benchmarking tools
└── middleware/
    ├── compression.py           # Response compression
    ├── caching_middleware.py    # HTTP caching headers
    └── rate_limiting.py         # Rate limiting implementation
```

### Features Implemented
- ✅ Database query optimization with comprehensive indexing strategy
- ✅ Advanced Redis caching with intelligent invalidation and clustering support
- ✅ Optimized connection pooling for high-concurrency scenarios
- ✅ Async request handling with concurrency control and batching
- ✅ Response compression and HTTP caching optimization
- ✅ Comprehensive performance monitoring with Prometheus metrics
- ✅ Real-time performance alerting and threshold monitoring
- ✅ Memory and CPU optimization within Kubernetes resource limits
- ✅ Cache warming strategies for frequently accessed data

## Acceptance Criteria

### API Performance
- [ ] API response times consistently under 100ms for 95th percentile across all endpoints
- [ ] Database queries execute in sub-50ms for standard operations
- [ ] Error handling maintains performance standards without degradation
- [ ] Pagination and filtering optimize large dataset operations
- [ ] Response compression reduces payload size by minimum 30% for applicable content

### Caching Effectiveness
- [ ] Cache hit ratio exceeds 80% for read operations across all services
- [ ] Cached operations demonstrate 3x+ performance improvement over non-cached
- [ ] Cache invalidation maintains data consistency without performance impact
- [ ] Memory usage for caching stays within allocated Kubernetes resource limits
- [ ] Cache warming reduces cold start latency by minimum 50%

### Database Optimization
- [ ] Connection pooling efficiently handles 500+ concurrent connections
- [ ] Database queries utilize proper indexes with execution plans validation
- [ ] Bulk operations process 1000+ records efficiently without timeout
- [ ] Transaction handling maintains ACID properties under high load
- [ ] Query performance monitoring identifies and alerts on slow operations

### Resource Utilization
- [ ] Memory usage optimized to stay within Kubernetes resource limits
- [ ] CPU utilization remains below 80% under normal load conditions
- [ ] Connection pools maintain optimal size without resource waste
- [ ] Async operations prevent blocking and improve throughput
- [ ] Background tasks execute without impacting request processing performance

This comprehensive performance optimization ensures all backend services meet stringent performance targets while maintaining scalability, reliability, and efficient resource utilization in both local development and production environments.