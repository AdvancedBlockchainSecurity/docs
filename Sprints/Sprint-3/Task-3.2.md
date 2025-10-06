# Task 3.2: Database Models and Repository Pattern

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 6 hours
**Owner**: Backend Team
**Priority**: P0 (Critical)
**Repository**: `solidity-security-data-service`

## Overview

Implement a comprehensive data access layer using the Repository Pattern with SQLAlchemy 2.0+, PostgreSQL 16, and Redis 7.2. This service provides high-performance data operations with intelligent caching strategies and supports the hybrid Python/Rust architecture for optimal performance.

## Technical Requirements

### Technology Stack
```yaml
Database: PostgreSQL 16 with JSONB support and advanced indexing
ORM: SQLAlchemy 2.0+ with async support and type safety
Migrations: Alembic 1.12+ with environment-specific configs
Connection Pool: asyncpg with optimized settings for high concurrency
Cache: Redis 7.2 with async client and advanced data types
Validation: Pydantic V2 with enhanced performance
Performance: Rust engine integration for high-throughput operations
```

### Development Standards
- **Async First**: Full async/await implementation for all I/O operations
- **Type Safety**: Comprehensive type hints with SQLAlchemy 2.0 typing
- **Performance**: Sub-50ms response times for standard queries
- **Caching**: Intelligent cache strategies with 3x+ performance improvement
- **Scalability**: Connection pooling optimized for high-concurrency scenarios

## Database Schema Design

### Core Entity Relationships
```sql
-- Users and Authentication
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    roles JSONB DEFAULT '[]'::jsonb,
    is_active BOOLEAN DEFAULT true,
    profile JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Projects and Organizations
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID REFERENCES organizations(id),
    settings JSONB DEFAULT '{}'::jsonb,
    metadata JSONB DEFAULT '{}'::jsonb,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Analysis Runs and Results
CREATE TABLE analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id UUID NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
    initiated_by UUID NOT NULL REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'pending',
    priority INTEGER DEFAULT 0,
    tool_configuration JSONB DEFAULT '{}'::jsonb,
    execution_metadata JSONB DEFAULT '{}'::jsonb,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Security Findings
CREATE TABLE findings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    tool_source VARCHAR(100) NOT NULL,
    finding_type VARCHAR(100) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    category VARCHAR(100),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    location JSONB, -- file, line, column info
    source_code JSONB, -- code snippet and context
    recommendation TEXT,
    metadata JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(50) DEFAULT 'open',
    assigned_to UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Trail
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(100),
    resource_id UUID,
    details JSONB DEFAULT '{}'::jsonb,
    ip_address INET,
    user_agent TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);
```

### Database Indexes and Performance
```sql
-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_active ON users(is_active) WHERE is_active = true;

-- Project indexes
CREATE INDEX idx_projects_owner ON projects(owner_id);
CREATE INDEX idx_projects_active ON projects(is_active) WHERE is_active = true;
CREATE INDEX idx_projects_name_search ON projects USING gin(to_tsvector('english', name));

-- Analysis indexes
CREATE INDEX idx_analyses_project ON analyses(project_id);
CREATE INDEX idx_analyses_status ON analyses(status);
CREATE INDEX idx_analyses_created ON analyses(created_at DESC);

-- Finding indexes
CREATE INDEX idx_findings_analysis ON findings(analysis_id);
CREATE INDEX idx_findings_severity ON findings(severity);
CREATE INDEX idx_findings_status ON findings(status);
CREATE INDEX idx_findings_tool ON findings(tool_source);
CREATE INDEX idx_findings_search ON findings USING gin(to_tsvector('english', title || ' ' || description));

-- Audit indexes
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp DESC);
CREATE INDEX idx_audit_action ON audit_logs(action);
```

## SQLAlchemy Models Implementation

### Base Model with Common Patterns
```python
# python-orm/src/models/base.py
from sqlalchemy import Column, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.ext.asyncio import AsyncAttrs
from typing import Any, Dict
import uuid
from datetime import datetime

Base = declarative_base()

class BaseModel(AsyncAttrs, Base):
    __abstract__ = True

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    def to_dict(self) -> Dict[str, Any]:
        """Convert model to dictionary for serialization"""
        return {
            column.name: getattr(self, column.name)
            for column in self.__table__.columns
        }

    def update_from_dict(self, data: Dict[str, Any]) -> None:
        """Update model from dictionary"""
        for key, value in data.items():
            if hasattr(self, key) and key not in ('id', 'created_at'):
                setattr(self, key, value)

    @classmethod
    def get_table_name(cls) -> str:
        return cls.__tablename__
```

### User Model with Advanced Features
```python
# python-orm/src/models/user.py
from sqlalchemy import Column, String, Boolean, JSON, Index
from sqlalchemy.orm import relationship
from sqlalchemy.ext.hybrid import hybrid_property
from typing import List, Dict, Any, Optional
from .base import BaseModel

class UserModel(BaseModel):
    __tablename__ = "users"

    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    roles = Column(JSON, default=list, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    profile = Column(JSON, default=dict, nullable=False)

    # Relationships
    projects = relationship("ProjectModel", back_populates="owner", lazy="selectin")
    analyses = relationship("AnalysisModel", back_populates="initiated_by", lazy="selectin")
    assigned_findings = relationship("FindingModel", back_populates="assigned_to", lazy="selectin")

    @hybrid_property
    def is_admin(self) -> bool:
        return "admin" in (self.roles or [])

    @hybrid_property
    def full_name(self) -> Optional[str]:
        if self.profile and isinstance(self.profile, dict):
            first_name = self.profile.get("first_name", "")
            last_name = self.profile.get("last_name", "")
            if first_name or last_name:
                return f"{first_name} {last_name}".strip()
        return None

    def has_role(self, role: str) -> bool:
        return role in (self.roles or [])

    def can_access_project(self, project_id: str) -> bool:
        return (
            self.is_admin or
            any(p.id == project_id for p in (self.projects or []))
        )

    # Table indexes for performance
    __table_args__ = (
        Index('idx_user_email_active', 'email', 'is_active'),
        Index('idx_user_roles_gin', 'roles', postgresql_using='gin'),
    )
```

### Project and Analysis Models
```python
# python-orm/src/models/project.py
from sqlalchemy import Column, String, Text, Boolean, JSON, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class ProjectModel(BaseModel):
    __tablename__ = "projects"

    name = Column(String(255), nullable=False)
    description = Column(Text)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    organization_id = Column(UUID(as_uuid=True), ForeignKey("organizations.id"))
    settings = Column(JSON, default=dict, nullable=False)
    metadata = Column(JSON, default=dict, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)

    # Relationships
    owner = relationship("UserModel", back_populates="projects")
    analyses = relationship("AnalysisModel", back_populates="project", cascade="all, delete-orphan")

    __table_args__ = (
        Index('idx_project_owner_active', 'owner_id', 'is_active'),
        Index('idx_project_name_search', 'name', postgresql_using='gin'),
    )

# python-orm/src/models/analysis.py
from sqlalchemy import Column, String, Integer, JSON, ForeignKey, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from .base import BaseModel

class AnalysisModel(BaseModel):
    __tablename__ = "analyses"

    project_id = Column(UUID(as_uuid=True), ForeignKey("projects.id", ondelete="CASCADE"), nullable=False)
    initiated_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    status = Column(String(50), default="pending", nullable=False)
    priority = Column(Integer, default=0, nullable=False)
    tool_configuration = Column(JSON, default=dict, nullable=False)
    execution_metadata = Column(JSON, default=dict, nullable=False)
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))

    # Relationships
    project = relationship("ProjectModel", back_populates="analyses")
    initiated_by_user = relationship("UserModel", back_populates="analyses")
    findings = relationship("FindingModel", back_populates="analysis", cascade="all, delete-orphan")

    __table_args__ = (
        Index('idx_analysis_project_status', 'project_id', 'status'),
        Index('idx_analysis_created_desc', 'created_at', postgresql_order_by='created_at DESC'),
    )
```

### Finding Model with Full-Text Search
```python
# python-orm/src/models/finding.py
from sqlalchemy import Column, String, Text, JSON, ForeignKey, DateTime, Index
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.ext.hybrid import hybrid_property
from .base import BaseModel

class FindingModel(BaseModel):
    __tablename__ = "findings"

    analysis_id = Column(UUID(as_uuid=True), ForeignKey("analyses.id", ondelete="CASCADE"), nullable=False)
    tool_source = Column(String(100), nullable=False)
    finding_type = Column(String(100), nullable=False)
    severity = Column(String(20), nullable=False)
    category = Column(String(100))
    title = Column(String(500), nullable=False)
    description = Column(Text)
    location = Column(JSON, default=dict)  # file, line, column
    source_code = Column(JSON, default=dict)  # code snippet and context
    recommendation = Column(Text)
    metadata = Column(JSON, default=dict, nullable=False)
    status = Column(String(50), default="open", nullable=False)
    assigned_to = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    resolved_at = Column(DateTime(timezone=True))

    # Relationships
    analysis = relationship("AnalysisModel", back_populates="findings")
    assigned_to_user = relationship("UserModel", back_populates="assigned_findings")

    @hybrid_property
    def severity_weight(self) -> int:
        severity_weights = {"critical": 4, "high": 3, "medium": 2, "low": 1, "info": 0}
        return severity_weights.get(self.severity.lower(), 0)

    @hybrid_property
    def is_resolved(self) -> bool:
        return self.status in ("resolved", "false_positive", "accepted_risk")

    __table_args__ = (
        Index('idx_finding_analysis_status', 'analysis_id', 'status'),
        Index('idx_finding_severity_created', 'severity', 'created_at'),
        Index('idx_finding_search_gin', 'title', 'description', postgresql_using='gin'),
    )
```

## Repository Pattern Implementation

### Base Repository with Common Operations
```python
# python-orm/src/repositories/base.py
from typing import TypeVar, Generic, List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, delete, func
from sqlalchemy.orm import selectinload
from abc import ABC, abstractmethod
import uuid

T = TypeVar('T')

class BaseRepository(Generic[T], ABC):
    def __init__(self, session: AsyncSession, model_class: type[T]):
        self.session = session
        self.model_class = model_class

    async def get_by_id(self, id: uuid.UUID) -> Optional[T]:
        result = await self.session.execute(
            select(self.model_class).where(self.model_class.id == id)
        )
        return result.scalar_one_or_none()

    async def get_all(self, skip: int = 0, limit: int = 100) -> List[T]:
        result = await self.session.execute(
            select(self.model_class).offset(skip).limit(limit)
        )
        return list(result.scalars().all())

    async def create(self, **kwargs) -> T:
        instance = self.model_class(**kwargs)
        self.session.add(instance)
        await self.session.flush()
        await self.session.refresh(instance)
        return instance

    async def update(self, id: uuid.UUID, **kwargs) -> Optional[T]:
        await self.session.execute(
            update(self.model_class)
            .where(self.model_class.id == id)
            .values(**kwargs)
        )
        return await self.get_by_id(id)

    async def delete(self, id: uuid.UUID) -> bool:
        result = await self.session.execute(
            delete(self.model_class).where(self.model_class.id == id)
        )
        return result.rowcount > 0

    async def count(self) -> int:
        result = await self.session.execute(
            select(func.count(self.model_class.id))
        )
        return result.scalar()

    async def exists(self, id: uuid.UUID) -> bool:
        result = await self.session.execute(
            select(func.count(self.model_class.id))
            .where(self.model_class.id == id)
        )
        return result.scalar() > 0
```

### Specialized User Repository
```python
# python-orm/src/repositories/user_repository.py
from typing import Optional, List
from sqlalchemy import select, and_, or_
from sqlalchemy.orm import selectinload
from .base import BaseRepository
from ..models.user import UserModel

class UserRepository(BaseRepository[UserModel]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, UserModel)

    async def get_by_email(self, email: str) -> Optional[UserModel]:
        result = await self.session.execute(
            select(UserModel)
            .where(UserModel.email == email)
            .options(selectinload(UserModel.projects))
        )
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> Optional[UserModel]:
        result = await self.session.execute(
            select(UserModel)
            .where(UserModel.username == username)
            .options(selectinload(UserModel.projects))
        )
        return result.scalar_one_or_none()

    async def search_users(self, query: str, limit: int = 10) -> List[UserModel]:
        search_filter = or_(
            UserModel.email.ilike(f"%{query}%"),
            UserModel.username.ilike(f"%{query}%")
        )
        result = await self.session.execute(
            select(UserModel)
            .where(and_(UserModel.is_active == True, search_filter))
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_users_by_role(self, role: str) -> List[UserModel]:
        result = await self.session.execute(
            select(UserModel)
            .where(UserModel.roles.contains([role]))
        )
        return list(result.scalars().all())

    async def get_active_users(self, skip: int = 0, limit: int = 100) -> List[UserModel]:
        result = await self.session.execute(
            select(UserModel)
            .where(UserModel.is_active == True)
            .offset(skip)
            .limit(limit)
        )
        return list(result.scalars().all())
```

### Finding Repository with Advanced Queries
```python
# python-orm/src/repositories/finding_repository.py
from typing import List, Dict, Any, Optional
from sqlalchemy import select, and_, func, desc
from sqlalchemy.orm import selectinload
from .base import BaseRepository
from ..models.finding import FindingModel

class FindingRepository(BaseRepository[FindingModel]):
    def __init__(self, session: AsyncSession):
        super().__init__(session, FindingModel)

    async def get_by_analysis(self, analysis_id: uuid.UUID) -> List[FindingModel]:
        result = await self.session.execute(
            select(FindingModel)
            .where(FindingModel.analysis_id == analysis_id)
            .options(selectinload(FindingModel.assigned_to_user))
            .order_by(desc(FindingModel.severity_weight), desc(FindingModel.created_at))
        )
        return list(result.scalars().all())

    async def get_by_project(self, project_id: uuid.UUID, status: Optional[str] = None) -> List[FindingModel]:
        query = (
            select(FindingModel)
            .join(FindingModel.analysis)
            .where(FindingModel.analysis.project_id == project_id)
        )

        if status:
            query = query.where(FindingModel.status == status)

        result = await self.session.execute(
            query.options(
                selectinload(FindingModel.analysis),
                selectinload(FindingModel.assigned_to_user)
            )
            .order_by(desc(FindingModel.severity_weight), desc(FindingModel.created_at))
        )
        return list(result.scalars().all())

    async def get_severity_summary(self, project_id: uuid.UUID) -> Dict[str, int]:
        result = await self.session.execute(
            select(FindingModel.severity, func.count(FindingModel.id))
            .join(FindingModel.analysis)
            .where(FindingModel.analysis.project_id == project_id)
            .group_by(FindingModel.severity)
        )

        summary = {severity: count for severity, count in result.all()}

        # Ensure all severity levels are represented
        for severity in ["critical", "high", "medium", "low", "info"]:
            summary.setdefault(severity, 0)

        return summary

    async def search_findings(
        self,
        query: str,
        project_id: Optional[uuid.UUID] = None,
        severity: Optional[str] = None,
        status: Optional[str] = None,
        limit: int = 50
    ) -> List[FindingModel]:
        filters = [
            or_(
                FindingModel.title.ilike(f"%{query}%"),
                FindingModel.description.ilike(f"%{query}%")
            )
        ]

        if project_id:
            filters.append(FindingModel.analysis.project_id == project_id)
        if severity:
            filters.append(FindingModel.severity == severity)
        if status:
            filters.append(FindingModel.status == status)

        result = await self.session.execute(
            select(FindingModel)
            .join(FindingModel.analysis)
            .where(and_(*filters))
            .options(
                selectinload(FindingModel.analysis),
                selectinload(FindingModel.assigned_to_user)
            )
            .order_by(desc(FindingModel.severity_weight), desc(FindingModel.created_at))
            .limit(limit)
        )
        return list(result.scalars().all())
```

## Redis Caching Implementation

### Cache Strategy and Configuration
```python
# python-orm/src/cache/redis_client.py
import json
import pickle
from typing import Any, Optional, Union, Dict, List
from redis.asyncio import Redis, ConnectionPool
from datetime import timedelta
import hashlib

class RedisCache:
    def __init__(self, redis_url: str, max_connections: int = 50):
        self.pool = ConnectionPool.from_url(
            redis_url,
            max_connections=max_connections,
            decode_responses=False  # Handle binary data for pickle
        )
        self.redis = Redis(connection_pool=self.pool)

    async def get(self, key: str, default: Any = None) -> Any:
        try:
            value = await self.redis.get(key)
            if value is None:
                return default
            return pickle.loads(value)
        except Exception:
            return default

    async def set(
        self,
        key: str,
        value: Any,
        ttl: Optional[Union[int, timedelta]] = None
    ) -> bool:
        try:
            serialized = pickle.dumps(value)
            if ttl:
                if isinstance(ttl, timedelta):
                    ttl = int(ttl.total_seconds())
                return await self.redis.setex(key, ttl, serialized)
            else:
                return await self.redis.set(key, serialized)
        except Exception:
            return False

    async def delete(self, key: str) -> bool:
        try:
            return bool(await self.redis.delete(key))
        except Exception:
            return False

    async def exists(self, key: str) -> bool:
        try:
            return bool(await self.redis.exists(key))
        except Exception:
            return False

    async def invalidate_pattern(self, pattern: str) -> int:
        try:
            keys = await self.redis.keys(pattern)
            if keys:
                return await self.redis.delete(*keys)
            return 0
        except Exception:
            return 0

    def make_key(self, *parts: str) -> str:
        """Generate a consistent cache key from parts"""
        key_string = ":".join(str(part) for part in parts)
        return f"solidity_security:{key_string}"

    def hash_key(self, data: Dict[str, Any]) -> str:
        """Generate a hash-based key for complex query parameters"""
        key_string = json.dumps(data, sort_keys=True)
        return hashlib.md5(key_string.encode()).hexdigest()
```

### Intelligent Caching Service
```python
# python-orm/src/services/cache_service.py
from typing import Any, Optional, Callable, Dict, List
from datetime import timedelta
from functools import wraps
from .redis_client import RedisCache
import asyncio

class CacheService:
    def __init__(self, redis_cache: RedisCache):
        self.cache = redis_cache

        # Cache TTL configurations
        self.ttl_config = {
            "user": timedelta(minutes=15),
            "project": timedelta(minutes=30),
            "analysis": timedelta(minutes=10),
            "finding": timedelta(minutes=5),
            "search": timedelta(minutes=2),
        }

    def cached(
        self,
        cache_type: str,
        key_generator: Optional[Callable] = None,
        ttl: Optional[timedelta] = None
    ):
        """Decorator for caching function results"""
        def decorator(func):
            @wraps(func)
            async def wrapper(*args, **kwargs):
                # Generate cache key
                if key_generator:
                    cache_key = key_generator(*args, **kwargs)
                else:
                    cache_key = self._default_key_generator(func.__name__, *args, **kwargs)

                # Try to get from cache
                cached_result = await self.cache.get(cache_key)
                if cached_result is not None:
                    return cached_result

                # Execute function and cache result
                result = await func(*args, **kwargs)
                if result is not None:
                    cache_ttl = ttl or self.ttl_config.get(cache_type, timedelta(minutes=5))
                    await self.cache.set(cache_key, result, cache_ttl)

                return result
            return wrapper
        return decorator

    def _default_key_generator(self, func_name: str, *args, **kwargs) -> str:
        """Generate a default cache key from function name and arguments"""
        key_parts = [func_name]

        # Add positional arguments
        for arg in args:
            if hasattr(arg, 'id'):  # Model instances
                key_parts.append(str(arg.id))
            elif isinstance(arg, (str, int, float, bool)):
                key_parts.append(str(arg))

        # Add keyword arguments
        if kwargs:
            sorted_kwargs = sorted(kwargs.items())
            key_hash = self.cache.hash_key(dict(sorted_kwargs))
            key_parts.append(key_hash)

        return self.cache.make_key(*key_parts)

    async def invalidate_user_cache(self, user_id: str):
        """Invalidate all cache entries for a specific user"""
        pattern = self.cache.make_key("*", user_id, "*")
        await self.cache.invalidate_pattern(pattern)

    async def invalidate_project_cache(self, project_id: str):
        """Invalidate all cache entries for a specific project"""
        pattern = self.cache.make_key("*", project_id, "*")
        await self.cache.invalidate_pattern(pattern)

    async def warm_cache(self, cache_operations: List[Callable]):
        """Pre-warm cache with frequently accessed data"""
        tasks = [operation() for operation in cache_operations]
        await asyncio.gather(*tasks, return_exceptions=True)
```

## Database Connection and Session Management

### Async Database Configuration
```python
# python-orm/src/core/database.py
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import QueuePool
from typing import AsyncGenerator
from contextlib import asynccontextmanager

class DatabaseManager:
    def __init__(self, database_url: str, **engine_kwargs):
        # Default engine configuration for high performance
        default_config = {
            "poolclass": QueuePool,
            "pool_size": 20,
            "max_overflow": 30,
            "pool_pre_ping": True,
            "pool_recycle": 3600,
            "echo": False,
        }
        default_config.update(engine_kwargs)

        self.engine = create_async_engine(database_url, **default_config)
        self.session_factory = async_sessionmaker(
            self.engine,
            class_=AsyncSession,
            expire_on_commit=False
        )

    @asynccontextmanager
    async def get_session(self) -> AsyncGenerator[AsyncSession, None]:
        async with self.session_factory() as session:
            try:
                yield session
                await session.commit()
            except Exception:
                await session.rollback()
                raise
            finally:
                await session.close()

    async def create_tables(self):
        from ..models.base import Base
        async with self.engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

    async def close(self):
        await self.engine.dispose()

# Dependency injection for FastAPI
async def get_db_session() -> AsyncGenerator[AsyncSession, None]:
    async with db_manager.get_session() as session:
        yield session
```

## Database Migrations with Alembic

### Migration Configuration
```python
# alembic/env.py
import asyncio
from logging.config import fileConfig
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import create_async_engine
from alembic import context
from solidity_security_shared.config import settings

# Import all models to ensure they're registered
from python_orm.src.models import *

config = context.config
fileConfig(config.config_file_name)

target_metadata = Base.metadata

def run_migrations_offline() -> None:
    url = settings.database_url
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()

def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()

async def run_async_migrations() -> None:
    connectable = create_async_engine(settings.database_url)

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()

def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
```

## Data Service API Implementation

### Main Data Service
```python
# python-orm/src/services/data_service.py
from typing import List, Optional, Dict, Any
from sqlalchemy.ext.asyncio import AsyncSession
from ..repositories import UserRepository, ProjectRepository, FindingRepository
from ..cache.cache_service import CacheService
from ..core.rust_bridge import RustDataEngine

class DataService:
    def __init__(
        self,
        session: AsyncSession,
        cache_service: CacheService,
        rust_engine: RustDataEngine
    ):
        self.session = session
        self.cache = cache_service
        self.rust_engine = rust_engine

        # Initialize repositories
        self.users = UserRepository(session)
        self.projects = ProjectRepository(session)
        self.findings = FindingRepository(session)

    @cache_service.cached("user")
    async def get_user_by_id(self, user_id: str) -> Optional[UserModel]:
        return await self.users.get_by_id(user_id)

    @cache_service.cached("project")
    async def get_project_with_analytics(self, project_id: str) -> Dict[str, Any]:
        project = await self.projects.get_by_id(project_id)
        if not project:
            return None

        # Use Rust engine for high-performance analytics
        analytics = await self.rust_engine.calculate_project_analytics(project_id)

        return {
            "project": project,
            "analytics": analytics,
            "finding_summary": await self.findings.get_severity_summary(project_id)
        }

    async def bulk_create_findings(self, findings_data: List[Dict[str, Any]]) -> List[FindingModel]:
        """High-performance bulk creation using Rust engine"""
        processed_data = await self.rust_engine.process_bulk_findings(findings_data)

        # Create findings in database
        findings = []
        for data in processed_data:
            finding = await self.findings.create(**data)
            findings.append(finding)

        return findings

    async def search_with_facets(
        self,
        query: str,
        filters: Dict[str, Any],
        page: int = 1,
        page_size: int = 20
    ) -> Dict[str, Any]:
        """Advanced search with faceted results using Rust engine"""
        search_params = {
            "query": query,
            "filters": filters,
            "page": page,
            "page_size": page_size
        }

        # Use Rust engine for high-performance search
        search_results = await self.rust_engine.faceted_search(search_params)

        return {
            "results": search_results["items"],
            "facets": search_results["facets"],
            "total": search_results["total"],
            "page": page,
            "page_size": page_size
        }
```

## Performance Monitoring and Optimization

### Database Performance Monitoring
```python
# python-orm/src/monitoring/db_metrics.py
from prometheus_client import Histogram, Counter, Gauge
from sqlalchemy import event
from sqlalchemy.engine import Engine
import time

# Metrics
DB_QUERY_DURATION = Histogram('db_query_duration_seconds', 'Database query duration')
DB_QUERY_COUNT = Counter('db_queries_total', 'Total database queries', ['operation'])
DB_CONNECTION_POOL = Gauge('db_connections_active', 'Active database connections')

@event.listens_for(Engine, "before_cursor_execute")
def receive_before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    context._query_start_time = time.time()

@event.listens_for(Engine, "after_cursor_execute")
def receive_after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
    total = time.time() - context._query_start_time
    DB_QUERY_DURATION.observe(total)

    # Determine operation type
    operation = statement.strip().split()[0].upper()
    DB_QUERY_COUNT.labels(operation=operation).inc()
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Repository Structure
```
python-orm/
├── src/
│   ├── models/                # SQLAlchemy models
│   │   ├── base.py           # Base model with common patterns
│   │   ├── user.py           # User model with advanced features
│   │   ├── project.py        # Project model
│   │   ├── analysis.py       # Analysis model
│   │   ├── finding.py        # Finding model with search
│   │   └── audit.py          # Audit trail model
│   ├── repositories/         # Repository pattern implementations
│   │   ├── base.py           # Base repository
│   │   ├── user_repository.py # User-specific operations
│   │   ├── project_repository.py # Project operations
│   │   └── finding_repository.py # Finding operations with search
│   ├── services/             # High-level data services
│   │   ├── data_service.py   # Main data service
│   │   ├── search_service.py # Search service
│   │   └── cache_service.py  # Cache management
│   ├── cache/                # Caching implementations
│   │   └── redis_client.py   # Redis cache client
│   ├── core/                 # Core infrastructure
│   │   ├── database.py       # Database configuration
│   │   ├── config.py         # Service configuration
│   │   └── rust_bridge.py    # Rust engine integration
│   └── api/                  # FastAPI endpoints
│       ├── router.py         # Data service API
│       ├── schemas.py        # Request/response schemas
│       └── dependencies.py   # API dependencies
├── alembic/                  # Database migrations
├── tests/                    # Comprehensive test suite
├── requirements.txt          # Python dependencies
└── README.md
```

### Features Implemented
- ✅ Comprehensive SQLAlchemy 2.0+ models with async support
- ✅ Repository pattern with advanced query capabilities
- ✅ Redis caching with intelligent invalidation strategies
- ✅ Database migrations with Alembic
- ✅ Connection pooling optimized for high concurrency
- ✅ Full-text search capabilities
- ✅ Rust engine integration for high-performance operations
- ✅ Performance monitoring and metrics
- ✅ Comprehensive test suite

## Acceptance Criteria

### Database Performance
- [ ] Database queries execute in sub-50ms for standard operations
- [ ] Connection pooling handles 500+ concurrent connections
- [ ] Full-text search returns results in under 100ms
- [ ] Bulk operations process 1000+ records efficiently

### Caching Effectiveness
- [ ] Cache hit ratio exceeds 80% for read operations
- [ ] Cached operations show 3x+ performance improvement
- [ ] Cache invalidation maintains data consistency
- [ ] Memory usage stays within configured limits

### Data Integrity
- [ ] All CRUD operations maintain ACID properties
- [ ] Foreign key constraints properly enforced
- [ ] Data validation prevents invalid states
- [ ] Audit trail captures all data modifications

### Integration Quality
- [ ] Repository pattern enables easy testing and mocking
- [ ] Rust engine integration provides performance benefits
- [ ] API endpoints follow RESTful conventions
- [ ] Error handling provides meaningful feedback

This comprehensive data service provides the foundation for all backend data operations with optimal performance, intelligent caching, and robust data integrity.