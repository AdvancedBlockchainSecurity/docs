# Task 3.7: Backend Integration Testing

**Sprint**: 3 - Core Backend Services Development
**Estimated Time**: 8 hours
**Owner**: Full Stack Team
**Priority**: P0 (Critical)
**Repository**: All backend services

## Overview

Implement a comprehensive testing strategy for all backend services including unit tests, integration tests, end-to-end tests, performance tests, and security tests. This task ensures robust validation of service-to-service communication, complete workflow functionality, and system reliability under various conditions while maintaining the local-first development approach.

## Technical Requirements

### Technology Stack
```yaml
Python Testing: pytest 7.4+ with async support and comprehensive plugins
Node.js Testing: Jest 29+ with TypeScript support and supertest
API Testing: httpx for async HTTP client testing with FastAPI
Database Testing: pytest-postgresql for isolated database testing
WebSocket Testing: Socket.IO client for real-time communication testing
Performance Testing: locust for distributed load generation
Security Testing: OWASP ZAP integration for security scanning
Coverage: pytest-cov and c8 for comprehensive coverage analysis
```

### Development Standards
- **Local-First Testing**: All tests run in local minikube environment first
- **Test Coverage**: 90%+ code coverage across all backend services
- **Test Isolation**: Each test runs in isolation with proper setup/teardown
- **Performance Standards**: Sub-100ms response times for 95th percentile
- **Security Validation**: Comprehensive authentication and authorization testing
- **CI/CD Integration**: Automated test execution in deployment pipeline

## Testing Architecture

### Test Environment Configuration
```yaml
# test-environments/local-test-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: test-config
  namespace: testing
data:
  database_url: "postgresql://test_user:test_pass@postgres-test:5432/test_db"
  redis_url: "redis://redis-test:6379/0"
  vault_addr: "http://vault-test:8200"
  vault_token: "test-token"
  test_mode: "true"
  log_level: "DEBUG"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-database
  namespace: testing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-database
  template:
    metadata:
      labels:
        app: test-database
    spec:
      containers:
      - name: postgres
        image: postgres:16
        env:
        - name: POSTGRES_DB
          value: "test_db"
        - name: POSTGRES_USER
          value: "test_user"
        - name: POSTGRES_PASSWORD
          value: "test_pass"
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        emptyDir: {}
```

### Test Base Classes and Fixtures
```python
# tests/conftest.py
import pytest
import asyncio
import httpx
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import StaticPool
from typing import AsyncGenerator, Dict, Any
import uuid
from datetime import datetime

from src.infrastructure.database import DatabaseManager
from src.models.base import Base
from src.models.user import UserModel
from src.models.project import ProjectModel
from src.services.auth_service import AuthService

# Global test configuration
@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture(scope="session")
async def test_database():
    """Create test database engine and session factory."""
    engine = create_async_engine(
        "postgresql+asyncpg://test_user:test_pass@localhost:5432/test_db",
        poolclass=StaticPool,
        connect_args={"check_same_thread": False},
        echo=False
    )

    # Create tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    session_factory = async_sessionmaker(
        engine,
        class_=AsyncSession,
        expire_on_commit=False
    )

    yield session_factory

    # Cleanup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()

@pytest.fixture
async def db_session(test_database) -> AsyncGenerator[AsyncSession, None]:
    """Create a database session for each test."""
    async with test_database() as session:
        yield session
        await session.rollback()

@pytest.fixture
async def test_user(db_session: AsyncSession) -> UserModel:
    """Create a test user for authentication tests."""
    user = UserModel(
        email="test@example.com",
        username="testuser",
        hashed_password="$2b$12$hash...",  # bcrypt hash for "testpassword"
        roles=["user"],
        is_active=True
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user

@pytest.fixture
async def admin_user(db_session: AsyncSession) -> UserModel:
    """Create a test admin user."""
    user = UserModel(
        email="admin@example.com",
        username="admin",
        hashed_password="$2b$12$hash...",
        roles=["admin", "user"],
        is_active=True
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user

@pytest.fixture
async def test_project(db_session: AsyncSession, test_user: UserModel) -> ProjectModel:
    """Create a test project."""
    project = ProjectModel(
        name="Test Project",
        description="A test project for integration testing",
        owner_id=test_user.id,
        settings={"analysis_tools": ["slither", "aderyn"]},
        is_active=True
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    return project

@pytest.fixture
async def authenticated_client(test_user: UserModel) -> httpx.AsyncClient:
    """Create an authenticated HTTP client."""
    from src.main import app
    from src.services.auth_service import AuthService

    auth_service = AuthService()
    token = auth_service.create_access_token(test_user)

    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(
        app=app,
        base_url="http://testserver",
        headers=headers
    ) as client:
        yield client

@pytest.fixture
async def admin_client(admin_user: UserModel) -> httpx.AsyncClient:
    """Create an authenticated admin HTTP client."""
    from src.main import app
    from src.services.auth_service import AuthService

    auth_service = AuthService()
    token = auth_service.create_access_token(admin_user)

    headers = {"Authorization": f"Bearer {token}"}

    async with httpx.AsyncClient(
        app=app,
        base_url="http://testserver",
        headers=headers
    ) as client:
        yield client
```

## Unit Testing Implementation

### Domain Layer Unit Tests
```python
# tests/unit/domain/test_user_entity.py
import pytest
from datetime import datetime
from src.domain.entities.user import User
from src.domain.value_objects import Email, UserId

class TestUserEntity:
    def test_user_creation_with_valid_data(self):
        """Test user entity creation with valid data."""
        user = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("test@example.com"),
            username="testuser",
            roles=["user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        assert user.email.value == "test@example.com"
        assert user.username == "testuser"
        assert user.is_active is True

    def test_user_has_role_returns_true_when_role_exists(self):
        """Test that has_role returns True when user has the specified role."""
        user = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("admin@example.com"),
            username="admin",
            roles=["admin", "user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        assert user.has_role("admin") is True
        assert user.has_role("user") is True
        assert user.has_role("moderator") is False

    def test_can_access_project_returns_true_for_owner(self):
        """Test that user can access their own project."""
        from src.domain.entities.project import Project
        from src.domain.value_objects import ProjectId

        user = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("owner@example.com"),
            username="owner",
            roles=["user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        project = Project(
            project_id=ProjectId("456e7890-e89b-12d3-a456-426614174000"),
            name="Test Project",
            owner_id=user.user_id,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        assert user.can_access_project(project) is True

    def test_can_access_project_returns_true_for_admin(self):
        """Test that admin can access any project."""
        from src.domain.entities.project import Project
        from src.domain.value_objects import ProjectId

        admin = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("admin@example.com"),
            username="admin",
            roles=["admin", "user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        project = Project(
            project_id=ProjectId("456e7890-e89b-12d3-a456-426614174000"),
            name="Test Project",
            owner_id=UserId("different-user-id"),
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        assert admin.can_access_project(project) is True

# tests/unit/domain/test_value_objects.py
class TestEmailValueObject:
    def test_valid_email_creation(self):
        """Test that valid email addresses are accepted."""
        valid_emails = [
            "test@example.com",
            "user.name@domain.co.uk",
            "admin+tag@company.org"
        ]

        for email_str in valid_emails:
            email = Email(email_str)
            assert email.value == email_str

    def test_invalid_email_raises_exception(self):
        """Test that invalid email addresses raise ValueError."""
        invalid_emails = [
            "invalid-email",
            "@domain.com",
            "user@",
            "user..name@domain.com"
        ]

        for email_str in invalid_emails:
            with pytest.raises(ValueError):
                Email(email_str)

    def test_email_immutability(self):
        """Test that email value objects are immutable."""
        email = Email("test@example.com")

        with pytest.raises(AttributeError):
            email.value = "changed@example.com"
```

### Application Layer Unit Tests
```python
# tests/unit/application/test_auth_handlers.py
import pytest
from unittest.mock import Mock, AsyncMock
from src.application.auth.handlers.auth_command_handlers import AuthCommandHandlers
from src.application.auth.commands.login_command import LoginCommand
from src.domain.entities.user import User
from src.domain.value_objects import Email, UserId

@pytest.mark.asyncio
class TestAuthCommandHandlers:
    async def test_handle_login_success(self):
        """Test successful login command handling."""
        # Arrange
        mock_auth_service = Mock()
        mock_user_repo = AsyncMock()

        user = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("test@example.com"),
            username="testuser",
            roles=["user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        mock_auth_service.authenticate_user = AsyncMock(return_value=user)
        mock_auth_service.generate_access_token = Mock(return_value="mock_token")

        handler = AuthCommandHandlers(mock_auth_service, mock_user_repo)
        command = LoginCommand(email="test@example.com", password="password")

        # Act
        result = await handler.handle_login(command)

        # Assert
        assert result.success is True
        assert result.token == "mock_token"
        assert result.user == user
        mock_auth_service.authenticate_user.assert_called_once()

    async def test_handle_login_failure(self):
        """Test failed login command handling."""
        # Arrange
        mock_auth_service = Mock()
        mock_user_repo = AsyncMock()

        mock_auth_service.authenticate_user = AsyncMock(return_value=None)

        handler = AuthCommandHandlers(mock_auth_service, mock_user_repo)
        command = LoginCommand(email="test@example.com", password="wrong_password")

        # Act
        result = await handler.handle_login(command)

        # Assert
        assert result.success is False
        assert result.error == "Invalid credentials"
        assert result.token is None
        mock_auth_service.authenticate_user.assert_called_once()

# tests/unit/application/test_query_handlers.py
@pytest.mark.asyncio
class TestUserQueryHandlers:
    async def test_handle_get_user_success(self):
        """Test successful user retrieval."""
        # Arrange
        mock_user_repo = AsyncMock()

        user = User(
            user_id=UserId("123e4567-e89b-12d3-a456-426614174000"),
            email=Email("test@example.com"),
            username="testuser",
            roles=["user"],
            is_active=True,
            created_at=datetime.utcnow(),
            updated_at=datetime.utcnow()
        )

        mock_user_repo.get_by_id = AsyncMock(return_value=user)

        handler = UserQueryHandlers(mock_user_repo)
        query = GetUserQuery(user_id="123e4567-e89b-12d3-a456-426614174000")

        # Act
        result = await handler.handle_get_user(query)

        # Assert
        assert result == user
        mock_user_repo.get_by_id.assert_called_once_with(
            UserId("123e4567-e89b-12d3-a456-426614174000")
        )

    async def test_handle_get_user_not_found(self):
        """Test user retrieval when user doesn't exist."""
        # Arrange
        mock_user_repo = AsyncMock()
        mock_user_repo.get_by_id = AsyncMock(return_value=None)

        handler = UserQueryHandlers(mock_user_repo)
        query = GetUserQuery(user_id="nonexistent-id")

        # Act
        result = await handler.handle_get_user(query)

        # Assert
        assert result is None
        mock_user_repo.get_by_id.assert_called_once()
```

## Integration Testing Implementation

### API Integration Tests
```python
# tests/integration/test_auth_endpoints.py
import pytest
import httpx

@pytest.mark.asyncio
class TestAuthEndpoints:
    async def test_user_registration_success(self, authenticated_client: httpx.AsyncClient):
        """Test successful user registration."""
        registration_data = {
            "email": "newuser@example.com",
            "username": "newuser",
            "password": "securepassword123",
            "confirm_password": "securepassword123"
        }

        response = await authenticated_client.post(
            "/api/v1/auth/register",
            json=registration_data
        )

        assert response.status_code == 201
        data = response.json()
        assert "access_token" in data
        assert data["user"]["email"] == registration_data["email"]
        assert data["user"]["username"] == registration_data["username"]

    async def test_user_login_success(self, test_user, authenticated_client: httpx.AsyncClient):
        """Test successful user login."""
        login_data = {
            "email": test_user.email,
            "password": "testpassword"
        }

        response = await authenticated_client.post(
            "/api/v1/auth/login",
            json=login_data
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["email"] == test_user.email

    async def test_user_login_invalid_credentials(self, authenticated_client: httpx.AsyncClient):
        """Test login with invalid credentials."""
        login_data = {
            "email": "nonexistent@example.com",
            "password": "wrongpassword"
        }

        response = await authenticated_client.post(
            "/api/v1/auth/login",
            json=login_data
        )

        assert response.status_code == 401
        data = response.json()
        assert "detail" in data

    async def test_token_refresh_success(self, test_user, authenticated_client: httpx.AsyncClient):
        """Test successful token refresh."""
        # First login to get refresh token
        login_response = await authenticated_client.post(
            "/api/v1/auth/login",
            json={"email": test_user.email, "password": "testpassword"}
        )

        refresh_token = login_response.json()["refresh_token"]

        # Refresh token
        response = await authenticated_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token}
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"

    async def test_protected_endpoint_without_token(self):
        """Test accessing protected endpoint without authentication."""
        async with httpx.AsyncClient(app=app, base_url="http://testserver") as client:
            response = await client.get("/api/v1/users/me")

            assert response.status_code == 401

    async def test_protected_endpoint_with_invalid_token(self):
        """Test accessing protected endpoint with invalid token."""
        headers = {"Authorization": "Bearer invalid-token"}

        async with httpx.AsyncClient(
            app=app,
            base_url="http://testserver",
            headers=headers
        ) as client:
            response = await client.get("/api/v1/users/me")

            assert response.status_code == 401

# tests/integration/test_project_endpoints.py
@pytest.mark.asyncio
class TestProjectEndpoints:
    async def test_create_project_success(self, authenticated_client: httpx.AsyncClient):
        """Test successful project creation."""
        project_data = {
            "name": "Integration Test Project",
            "description": "A project created during integration testing",
            "settings": {
                "analysis_tools": ["slither", "aderyn"],
                "notification_preferences": ["email", "slack"]
            }
        }

        response = await authenticated_client.post(
            "/api/v1/projects",
            json=project_data
        )

        assert response.status_code == 201
        data = response.json()
        assert data["name"] == project_data["name"]
        assert data["description"] == project_data["description"]
        assert "id" in data
        assert "created_at" in data

    async def test_get_project_success(
        self,
        authenticated_client: httpx.AsyncClient,
        test_project
    ):
        """Test successful project retrieval."""
        response = await authenticated_client.get(f"/api/v1/projects/{test_project.id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(test_project.id)
        assert data["name"] == test_project.name

    async def test_get_project_unauthorized(
        self,
        test_project
    ):
        """Test project retrieval without authorization."""
        async with httpx.AsyncClient(app=app, base_url="http://testserver") as client:
            response = await client.get(f"/api/v1/projects/{test_project.id}")

            assert response.status_code == 401

    async def test_list_user_projects(
        self,
        authenticated_client: httpx.AsyncClient,
        test_project
    ):
        """Test listing user's projects."""
        response = await authenticated_client.get("/api/v1/projects")

        assert response.status_code == 200
        data = response.json()
        assert "items" in data
        assert len(data["items"]) >= 1

        # Check that test project is in the list
        project_ids = [item["id"] for item in data["items"]]
        assert str(test_project.id) in project_ids
```

### Service-to-Service Integration Tests
```python
# tests/integration/test_service_communication.py
import pytest
import httpx
from unittest.mock import AsyncMock, patch

@pytest.mark.asyncio
class TestServiceCommunication:
    async def test_api_service_to_data_service_communication(self):
        """Test communication between API service and Data service."""
        # Mock the data service response
        mock_response = {
            "user_id": "123e4567-e89b-12d3-a456-426614174000",
            "email": "test@example.com",
            "username": "testuser"
        }

        with patch('httpx.AsyncClient.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.json.return_value = mock_response

            from src.services.data_service_client import DataServiceClient

            client = DataServiceClient("http://data-service:3001")
            result = await client.get_user_by_id("123e4567-e89b-12d3-a456-426614174000")

            assert result["user_id"] == mock_response["user_id"]
            mock_get.assert_called_once()

    async def test_api_service_to_notification_service_communication(self):
        """Test communication between API service and Notification service."""
        notification_data = {
            "type": "email",
            "recipients": ["test@example.com"],
            "template": "welcome",
            "data": {"username": "testuser"},
            "priority": "normal"
        }

        with patch('httpx.AsyncClient.post') as mock_post:
            mock_post.return_value.status_code = 200
            mock_post.return_value.json.return_value = {"success": True}

            from src.services.notification_service_client import NotificationServiceClient

            client = NotificationServiceClient("http://notification-service:3002")
            result = await client.send_notification(notification_data)

            assert result["success"] is True
            mock_post.assert_called_once()

    async def test_circuit_breaker_functionality(self):
        """Test circuit breaker pattern during service failures."""
        from src.infrastructure.resilience.circuit_breaker import CircuitBreaker

        # Create circuit breaker with low threshold for testing
        circuit_breaker = CircuitBreaker(
            failure_threshold=2,
            recovery_timeout=5,
            expected_exception=httpx.RequestError
        )

        # Mock a failing service call
        async def failing_service_call():
            raise httpx.RequestError("Service unavailable")

        # First two calls should fail and open the circuit
        with pytest.raises(httpx.RequestError):
            await circuit_breaker.call(failing_service_call)

        with pytest.raises(httpx.RequestError):
            await circuit_breaker.call(failing_service_call)

        # Third call should be blocked by open circuit
        from src.infrastructure.resilience.exceptions import CircuitBreakerOpenError
        with pytest.raises(CircuitBreakerOpenError):
            await circuit_breaker.call(failing_service_call)

    async def test_jwt_token_propagation(self, authenticated_client: httpx.AsyncClient):
        """Test JWT token propagation between services."""
        # Mock inter-service call that requires authentication
        with patch('httpx.AsyncClient.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.json.return_value = {"status": "authorized"}

            response = await authenticated_client.get("/api/v1/users/me")

            assert response.status_code == 200

            # Verify that the service call included the authorization header
            called_headers = mock_get.call_args[1].get('headers', {})
            assert 'Authorization' in called_headers
            assert called_headers['Authorization'].startswith('Bearer ')
```

### Database Integration Tests
```python
# tests/integration/test_database_operations.py
import pytest
from sqlalchemy.ext.asyncio import AsyncSession

@pytest.mark.asyncio
class TestDatabaseOperations:
    async def test_user_repository_crud_operations(self, db_session: AsyncSession):
        """Test complete CRUD operations for User repository."""
        from src.repositories.user_repository import UserRepository

        user_repo = UserRepository(db_session)

        # Create
        user_data = {
            "email": "crud@example.com",
            "username": "cruduser",
            "hashed_password": "hashedpassword",
            "roles": ["user"],
            "is_active": True
        }

        created_user = await user_repo.create(**user_data)
        assert created_user.email == user_data["email"]
        assert created_user.id is not None

        # Read
        retrieved_user = await user_repo.get_by_id(created_user.id)
        assert retrieved_user.email == created_user.email

        # Update
        updated_user = await user_repo.update(
            created_user.id,
            roles=["user", "premium"]
        )
        assert "premium" in updated_user.roles

        # Delete
        deletion_success = await user_repo.delete(created_user.id)
        assert deletion_success is True

        # Verify deletion
        deleted_user = await user_repo.get_by_id(created_user.id)
        assert deleted_user is None

    async def test_database_transaction_rollback(self, db_session: AsyncSession):
        """Test database transaction rollback on errors."""
        from src.repositories.user_repository import UserRepository

        user_repo = UserRepository(db_session)

        try:
            # Start transaction
            user1 = await user_repo.create(
                email="transaction1@example.com",
                username="transactionuser1",
                hashed_password="hash",
                roles=["user"]
            )

            # This should fail due to duplicate email
            user2 = await user_repo.create(
                email="transaction1@example.com",  # Duplicate email
                username="transactionuser2",
                hashed_password="hash",
                roles=["user"]
            )

            await db_session.commit()

        except Exception:
            await db_session.rollback()

            # Verify first user was also rolled back
            rolled_back_user = await user_repo.get_by_email("transaction1@example.com")
            assert rolled_back_user is None

    async def test_database_connection_pooling(self, test_database):
        """Test database connection pooling under concurrent load."""
        import asyncio
        from src.repositories.user_repository import UserRepository

        async def create_user_concurrent(session_factory, index):
            async with session_factory() as session:
                user_repo = UserRepository(session)
                user = await user_repo.create(
                    email=f"concurrent{index}@example.com",
                    username=f"concurrent{index}",
                    hashed_password="hash",
                    roles=["user"]
                )
                await session.commit()
                return user

        # Create 20 users concurrently
        tasks = [
            create_user_concurrent(test_database, i)
            for i in range(20)
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)

        # Verify all users were created successfully
        successful_creations = [r for r in results if not isinstance(r, Exception)]
        assert len(successful_creations) == 20
```

## WebSocket Integration Tests

### Real-Time Communication Tests
```typescript
// tests/integration/websocket.test.ts
import { io, Socket } from 'socket.io-client';
import { createServer } from 'http';
import { AddressInfo } from 'net';

describe('WebSocket Integration Tests', () => {
  let server: any;
  let serverSocket: Socket;
  let clientSocket: Socket;
  let port: number;

  beforeAll((done) => {
    const httpServer = createServer();
    const io = new Server(httpServer);

    server = httpServer.listen(() => {
      port = (server.address() as AddressInfo).port;

      io.on('connection', (socket) => {
        serverSocket = socket;
      });

      done();
    });
  });

  afterAll(() => {
    server.close();
  });

  beforeEach((done) => {
    clientSocket = io(`http://localhost:${port}`, {
      auth: {
        token: 'test-jwt-token'
      }
    });

    clientSocket.on('connect', done);
  });

  afterEach(() => {
    clientSocket.close();
  });

  test('should authenticate user with valid JWT token', (done) => {
    clientSocket.on('authenticated', (data) => {
      expect(data.success).toBe(true);
      expect(data.userId).toBeDefined();
      done();
    });

    clientSocket.emit('authenticate', { token: 'test-jwt-token' });
  });

  test('should join user-specific notification room', (done) => {
    const userId = 'test-user-id';

    clientSocket.on('room-joined', (data) => {
      expect(data.room).toBe(`user:${userId}`);
      done();
    });

    clientSocket.emit('join-room', { room: `user:${userId}` });
  });

  test('should receive real-time analysis updates', (done) => {
    const analysisUpdate = {
      analysisId: 'test-analysis-id',
      status: 'running',
      progress: 50,
      currentTool: 'slither'
    };

    clientSocket.on('analysis:progress', (data) => {
      expect(data.analysisId).toBe(analysisUpdate.analysisId);
      expect(data.progress).toBe(analysisUpdate.progress);
      done();
    });

    // Simulate server sending update
    serverSocket.emit('analysis:progress', analysisUpdate);
  });

  test('should handle connection drops and reconnection', (done) => {
    let reconnectCount = 0;

    clientSocket.on('reconnect', () => {
      reconnectCount++;
      if (reconnectCount === 1) {
        expect(clientSocket.connected).toBe(true);
        done();
      }
    });

    // Simulate connection drop
    clientSocket.disconnect();

    // Reconnect after short delay
    setTimeout(() => {
      clientSocket.connect();
    }, 100);
  });

  test('should validate room permissions', (done) => {
    clientSocket.on('error', (error) => {
      expect(error.message).toContain('insufficient permissions');
      done();
    });

    // Try to join admin room without admin privileges
    clientSocket.emit('join-room', { room: 'admin:notifications' });
  });
});
```

## Performance Testing Implementation

### Load Testing with Locust
```python
# tests/performance/locustfile.py
from locust import HttpUser, task, between
import json
import random

class SoliditySecurityUser(HttpUser):
    wait_time = between(1, 3)

    def on_start(self):
        """Login and get authentication token."""
        response = self.client.post("/api/v1/auth/login", json={
            "email": f"loadtest{random.randint(1, 100)}@example.com",
            "password": "loadtestpassword"
        })

        if response.status_code == 200:
            self.token = response.json()["access_token"]
            self.headers = {"Authorization": f"Bearer {self.token}"}
        else:
            self.token = None
            self.headers = {}

    @task(3)
    def get_user_profile(self):
        """Test user profile endpoint."""
        if self.token:
            self.client.get("/api/v1/users/me", headers=self.headers)

    @task(2)
    def list_projects(self):
        """Test project listing endpoint."""
        if self.token:
            self.client.get("/api/v1/projects", headers=self.headers)

    @task(1)
    def create_project(self):
        """Test project creation endpoint."""
        if self.token:
            project_data = {
                "name": f"Load Test Project {random.randint(1, 1000)}",
                "description": "A project created during load testing",
                "settings": {
                    "analysis_tools": ["slither"],
                    "notification_preferences": ["email"]
                }
            }

            self.client.post(
                "/api/v1/projects",
                json=project_data,
                headers=self.headers
            )

    @task(1)
    def search_findings(self):
        """Test finding search endpoint."""
        if self.token:
            search_params = {
                "query": "vulnerability",
                "severity": random.choice(["high", "medium", "low"]),
                "limit": 20
            }

            self.client.get(
                "/api/v1/findings/search",
                params=search_params,
                headers=self.headers
            )

class DatabasePerformanceUser(HttpUser):
    """User class focused on database-heavy operations."""
    wait_time = between(0.5, 1.5)

    def on_start(self):
        self.authenticate()

    def authenticate(self):
        response = self.client.post("/api/v1/auth/login", json={
            "email": "dbtest@example.com",
            "password": "dbtestpassword"
        })

        if response.status_code == 200:
            self.token = response.json()["access_token"]
            self.headers = {"Authorization": f"Bearer {self.token}"}

    @task(5)
    def complex_analytics_query(self):
        """Test complex analytics endpoint that hits database hard."""
        if hasattr(self, 'token') and self.token:
            self.client.get(
                "/api/v1/analytics/security-trends",
                params={"period": "30d"},
                headers=self.headers
            )

    @task(3)
    def bulk_finding_creation(self):
        """Test bulk finding creation."""
        if hasattr(self, 'token') and self.token:
            findings_data = [
                {
                    "title": f"Test Finding {i}",
                    "severity": random.choice(["critical", "high", "medium", "low"]),
                    "category": "security",
                    "tool_source": "slither",
                    "description": f"Test finding {i} description"
                }
                for i in range(10)
            ]

            self.client.post(
                "/api/v1/findings/bulk",
                json={"findings": findings_data},
                headers=self.headers
            )

# Performance test configuration
# tests/performance/performance_config.py
PERFORMANCE_TARGETS = {
    "api_response_time_95th_percentile": 100,  # milliseconds
    "database_query_time_95th_percentile": 50,  # milliseconds
    "websocket_connection_time": 500,  # milliseconds
    "concurrent_users_supported": 1000,
    "requests_per_second": 500,
    "error_rate_threshold": 0.01  # 1%
}

def validate_performance_results(stats):
    """Validate performance test results against targets."""
    failures = []

    # Check response times
    if stats.get('response_time_95th') > PERFORMANCE_TARGETS['api_response_time_95th_percentile']:
        failures.append(f"API response time too high: {stats['response_time_95th']}ms")

    # Check error rates
    if stats.get('error_rate', 0) > PERFORMANCE_TARGETS['error_rate_threshold']:
        failures.append(f"Error rate too high: {stats['error_rate']:.2%}")

    # Check throughput
    if stats.get('requests_per_second', 0) < PERFORMANCE_TARGETS['requests_per_second']:
        failures.append(f"Throughput too low: {stats['requests_per_second']} req/s")

    return failures
```

## Security Testing Implementation

### Authentication and Authorization Tests
```python
# tests/security/test_auth_security.py
import pytest
import httpx
import jwt
from datetime import datetime, timedelta

@pytest.mark.asyncio
class TestAuthenticationSecurity:
    async def test_jwt_token_expiration(self, authenticated_client: httpx.AsyncClient):
        """Test that expired JWT tokens are rejected."""
        # Create an expired token
        expired_payload = {
            "sub": "test-user-id",
            "exp": datetime.utcnow() - timedelta(hours=1),  # Expired 1 hour ago
            "roles": ["user"]
        }

        expired_token = jwt.encode(expired_payload, "test-secret", algorithm="HS256")
        headers = {"Authorization": f"Bearer {expired_token}"}

        async with httpx.AsyncClient(
            app=app,
            base_url="http://testserver",
            headers=headers
        ) as client:
            response = await client.get("/api/v1/users/me")

            assert response.status_code == 401
            assert "expired" in response.json()["detail"].lower()

    async def test_jwt_token_tampering(self):
        """Test that tampered JWT tokens are rejected."""
        # Create a valid token and tamper with it
        valid_payload = {
            "sub": "test-user-id",
            "exp": datetime.utcnow() + timedelta(hours=1),
            "roles": ["user"]
        }

        valid_token = jwt.encode(valid_payload, "test-secret", algorithm="HS256")

        # Tamper with the token by changing a character
        tampered_token = valid_token[:-5] + "XXXXX"
        headers = {"Authorization": f"Bearer {tampered_token}"}

        async with httpx.AsyncClient(
            app=app,
            base_url="http://testserver",
            headers=headers
        ) as client:
            response = await client.get("/api/v1/users/me")

            assert response.status_code == 401

    async def test_role_based_access_control(self, test_user, admin_user):
        """Test RBAC enforcement."""
        from src.services.auth_service import AuthService

        auth_service = AuthService()

        # Test user accessing admin endpoint
        user_token = auth_service.create_access_token(test_user)
        user_headers = {"Authorization": f"Bearer {user_token}"}

        async with httpx.AsyncClient(
            app=app,
            base_url="http://testserver",
            headers=user_headers
        ) as client:
            response = await client.get("/api/v1/admin/users")

            assert response.status_code == 403

        # Test admin accessing admin endpoint
        admin_token = auth_service.create_access_token(admin_user)
        admin_headers = {"Authorization": f"Bearer {admin_token}"}

        async with httpx.AsyncClient(
            app=app,
            base_url="http://testserver",
            headers=admin_headers
        ) as client:
            response = await client.get("/api/v1/admin/users")

            assert response.status_code == 200

    async def test_password_hashing_security(self, db_session):
        """Test that passwords are properly hashed."""
        from src.repositories.user_repository import UserRepository
        from src.services.password_service import PasswordService

        user_repo = UserRepository(db_session)
        password_service = PasswordService()

        plain_password = "testsecretpassword"
        hashed_password = password_service.hash_password(plain_password)

        # Create user with hashed password
        user = await user_repo.create(
            email="passwordtest@example.com",
            username="passwordtest",
            hashed_password=hashed_password,
            roles=["user"]
        )

        # Verify password is hashed
        assert user.hashed_password != plain_password
        assert user.hashed_password.startswith("$2b$")

        # Verify password verification works
        assert password_service.verify_password(plain_password, user.hashed_password)
        assert not password_service.verify_password("wrongpassword", user.hashed_password)

# tests/security/test_data_protection.py
@pytest.mark.asyncio
class TestDataProtection:
    async def test_sensitive_data_encryption(self):
        """Test that sensitive data is encrypted in transit."""
        from src.infrastructure.security.encryption import DataEncryption

        encryption = DataEncryption()

        sensitive_data = "user-sensitive-information"
        encrypted_data = await encryption.encrypt(sensitive_data)

        # Verify data is encrypted
        assert encrypted_data != sensitive_data
        assert len(encrypted_data) > len(sensitive_data)

        # Verify decryption works
        decrypted_data = await encryption.decrypt(encrypted_data)
        assert decrypted_data == sensitive_data

    async def test_sql_injection_prevention(self, authenticated_client: httpx.AsyncClient):
        """Test SQL injection attack prevention."""
        # Attempt SQL injection in search parameter
        malicious_query = "'; DROP TABLE users; --"

        response = await authenticated_client.get(
            "/api/v1/findings/search",
            params={"query": malicious_query}
        )

        # Should return normal response, not error from SQL injection
        assert response.status_code in [200, 400]  # 400 for validation error is acceptable

        # Verify database is still intact by making a normal request
        normal_response = await authenticated_client.get("/api/v1/users/me")
        assert normal_response.status_code == 200

    async def test_xss_prevention(self, authenticated_client: httpx.AsyncClient):
        """Test XSS attack prevention."""
        xss_payload = "<script>alert('xss')</script>"

        project_data = {
            "name": xss_payload,
            "description": f"Project with XSS payload: {xss_payload}"
        }

        response = await authenticated_client.post(
            "/api/v1/projects",
            json=project_data
        )

        if response.status_code == 201:
            # If creation succeeded, verify XSS payload is escaped
            project = response.json()
            assert "<script>" not in project["name"]
            assert "&lt;script&gt;" in project["name"]
```

## End-to-End Testing Implementation

### Complete Workflow Tests
```python
# tests/e2e/test_complete_workflows.py
import pytest
import httpx
import asyncio
from unittest.mock import patch

@pytest.mark.asyncio
class TestCompleteWorkflows:
    async def test_user_registration_to_analysis_workflow(self):
        """Test complete workflow from user registration to running analysis."""
        async with httpx.AsyncClient(app=app, base_url="http://testserver") as client:
            # Step 1: User Registration
            registration_data = {
                "email": "workflow@example.com",
                "username": "workflowuser",
                "password": "securepassword123",
                "confirm_password": "securepassword123"
            }

            register_response = await client.post(
                "/api/v1/auth/register",
                json=registration_data
            )

            assert register_response.status_code == 201
            access_token = register_response.json()["access_token"]

            # Step 2: Create Project
            headers = {"Authorization": f"Bearer {access_token}"}

            project_data = {
                "name": "E2E Test Project",
                "description": "End-to-end testing project",
                "settings": {
                    "analysis_tools": ["slither", "aderyn"],
                    "notification_preferences": ["email"]
                }
            }

            project_response = await client.post(
                "/api/v1/projects",
                json=project_data,
                headers=headers
            )

            assert project_response.status_code == 201
            project_id = project_response.json()["id"]

            # Step 3: Upload Solidity Files (mocked)
            with patch('src.services.file_service.upload_files') as mock_upload:
                mock_upload.return_value = {
                    "files": ["contract.sol", "token.sol"],
                    "upload_id": "test-upload-id"
                }

                upload_response = await client.post(
                    f"/api/v1/projects/{project_id}/files",
                    files={"files": ("contract.sol", "pragma solidity ^0.8.0;", "text/plain")},
                    headers=headers
                )

                assert upload_response.status_code == 200

            # Step 4: Start Analysis
            analysis_data = {
                "tools": ["slither"],
                "priority": "normal"
            }

            with patch('src.services.analysis_service.start_analysis') as mock_analysis:
                mock_analysis.return_value = {
                    "analysis_id": "test-analysis-id",
                    "status": "started"
                }

                analysis_response = await client.post(
                    f"/api/v1/projects/{project_id}/analyses",
                    json=analysis_data,
                    headers=headers
                )

                assert analysis_response.status_code == 201
                analysis_id = analysis_response.json()["analysis_id"]

            # Step 5: Check Analysis Status
            status_response = await client.get(
                f"/api/v1/analyses/{analysis_id}",
                headers=headers
            )

            assert status_response.status_code == 200
            assert status_response.json()["status"] in ["started", "running", "completed"]

            # Step 6: Get Results (when available)
            results_response = await client.get(
                f"/api/v1/analyses/{analysis_id}/results",
                headers=headers
            )

            # Should work regardless of analysis status
            assert results_response.status_code in [200, 202]  # 202 for still processing

    async def test_real_time_notification_workflow(self):
        """Test real-time notification delivery workflow."""
        import socketio

        # Create authenticated Socket.IO client
        sio = socketio.AsyncClient()

        events_received = []

        @sio.event
        async def analysis_progress(data):
            events_received.append(('analysis_progress', data))

        @sio.event
        async def analysis_completed(data):
            events_received.append(('analysis_completed', data))

        # Connect with authentication
        await sio.connect('http://localhost:3002', auth={'token': 'test-jwt-token'})

        # Join user-specific room
        await sio.emit('join_room', {'room': 'user:test-user-id'})

        # Simulate analysis progress updates
        progress_events = [
            {'analysis_id': 'test-analysis', 'progress': 25, 'tool': 'slither'},
            {'analysis_id': 'test-analysis', 'progress': 50, 'tool': 'slither'},
            {'analysis_id': 'test-analysis', 'progress': 75, 'tool': 'aderyn'},
            {'analysis_id': 'test-analysis', 'progress': 100, 'status': 'completed'}
        ]

        for event in progress_events[:-1]:
            await sio.emit('analysis_progress', event)
            await asyncio.sleep(0.1)  # Small delay between events

        # Send completion event
        await sio.emit('analysis_completed', progress_events[-1])

        # Wait for events to be processed
        await asyncio.sleep(1)

        # Verify events were received
        assert len(events_received) >= 3
        assert any(event[0] == 'analysis_progress' for event in events_received)
        assert any(event[0] == 'analysis_completed' for event in events_received)

        await sio.disconnect()

    async def test_error_recovery_workflow(self, authenticated_client: httpx.AsyncClient):
        """Test system behavior during various error scenarios."""
        # Test 1: Service unavailable error
        with patch('httpx.AsyncClient.get') as mock_get:
            mock_get.side_effect = httpx.RequestError("Service unavailable")

            response = await authenticated_client.get("/api/v1/external-service-data")

            # Should return graceful error response
            assert response.status_code == 503
            assert "service unavailable" in response.json()["detail"].lower()

        # Test 2: Database connection error
        with patch('sqlalchemy.ext.asyncio.AsyncSession.execute') as mock_execute:
            mock_execute.side_effect = Exception("Database connection lost")

            response = await authenticated_client.get("/api/v1/projects")

            # Should return database error response
            assert response.status_code == 500
            assert "database" in response.json()["detail"].lower()

        # Test 3: Recovery after error
        # Normal request should work after error
        response = await authenticated_client.get("/api/v1/users/me")
        assert response.status_code == 200
```

## Test Automation and CI/CD Integration

### GitHub Actions Workflow
```yaml
# .github/workflows/backend-tests.yml
name: Backend Integration Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: testpassword
          POSTGRES_USER: testuser
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7.2
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

      vault:
        image: hashicorp/vault:1.15
        env:
          VAULT_DEV_ROOT_TOKEN_ID: testtoken
          VAULT_DEV_LISTEN_ADDRESS: 0.0.0.0:8200
        options: >-
          --cap-add=IPC_LOCK
        ports:
          - 8200:8200

    steps:
    - uses: actions/checkout@v4

    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.13'

    - name: Set up Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'

    - name: Install Python dependencies
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements-test.txt

    - name: Install Node.js dependencies
      run: |
        cd notification-service
        npm ci

    - name: Wait for services
      run: |
        ./scripts/wait-for-services.sh

    - name: Initialize test database
      run: |
        python -m alembic upgrade head
      env:
        DATABASE_URL: postgresql://testuser:testpassword@localhost:5432/testdb

    - name: Run Python unit tests
      run: |
        pytest tests/unit/ -v --cov=src --cov-report=xml
      env:
        DATABASE_URL: postgresql://testuser:testpassword@localhost:5432/testdb
        REDIS_URL: redis://localhost:6379/0
        VAULT_ADDR: http://localhost:8200
        VAULT_TOKEN: testtoken

    - name: Run Python integration tests
      run: |
        pytest tests/integration/ -v --cov=src --cov-append --cov-report=xml
      env:
        DATABASE_URL: postgresql://testuser:testpassword@localhost:5432/testdb
        REDIS_URL: redis://localhost:6379/0
        VAULT_ADDR: http://localhost:8200
        VAULT_TOKEN: testtoken

    - name: Run Node.js tests
      run: |
        cd notification-service
        npm test
      env:
        REDIS_URL: redis://localhost:6379/0
        VAULT_ADDR: http://localhost:8200
        VAULT_TOKEN: testtoken

    - name: Run E2E tests
      run: |
        pytest tests/e2e/ -v
      env:
        DATABASE_URL: postgresql://testuser:testpassword@localhost:5432/testdb
        REDIS_URL: redis://localhost:6379/0
        VAULT_ADDR: http://localhost:8200
        VAULT_TOKEN: testtoken

    - name: Run performance tests
      run: |
        locust --headless --users 50 --spawn-rate 5 --run-time 2m --host http://localhost:8000

    - name: Upload coverage reports
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.xml
        flags: backend
        name: backend-coverage

  security-tests:
    runs-on: ubuntu-latest
    needs: test

    steps:
    - uses: actions/checkout@v4

    - name: Run security scan
      uses: securecodewarrior/github-action-add-sarif@v1
      with:
        sarif-file: security-results.sarif

    - name: Run dependency check
      run: |
        pip install safety
        safety check --json --output safety-report.json
```

## Standards Reference
- **Kubernetes Structure**: Follow the standardized directory structure defined in `docs/architecture-templates/kubernetes-kustomize-structure-template.md`
- **Secret Management**: All Kubernetes secrets must be stored in HashiCorp Vault and synchronized to clusters using External Secrets Operator. No secrets should be committed to Git repositories.

## Deliverables

### Test Structure
```
tests/
├── conftest.py                    # Global test configuration and fixtures
├── unit/                         # Unit tests for individual components
│   ├── domain/                   # Domain layer tests
│   │   ├── test_entities.py      # Entity tests
│   │   ├── test_value_objects.py # Value object tests
│   │   └── test_services.py      # Domain service tests
│   ├── application/              # Application layer tests
│   │   ├── test_command_handlers.py # Command handler tests
│   │   ├── test_query_handlers.py   # Query handler tests
│   │   └── test_use_cases.py        # Use case tests
│   └── infrastructure/           # Infrastructure layer tests
│       ├── test_repositories.py  # Repository tests
│       ├── test_external_services.py # External service tests
│       └── test_security.py      # Security component tests
├── integration/                  # Integration tests
│   ├── test_api_endpoints.py     # API endpoint tests
│   ├── test_service_communication.py # Inter-service tests
│   ├── test_database_operations.py   # Database integration tests
│   └── test_websocket.py         # WebSocket integration tests
├── e2e/                         # End-to-end tests
│   ├── test_complete_workflows.py # Complete user workflows
│   ├── test_error_scenarios.py   # Error handling and recovery
│   └── test_performance.py       # Performance validation
├── security/                    # Security tests
│   ├── test_auth_security.py     # Authentication security
│   ├── test_data_protection.py   # Data protection tests
│   └── test_vulnerability_scan.py # Vulnerability scanning
├── performance/                 # Performance tests
│   ├── locustfile.py            # Load testing scenarios
│   ├── stress_tests.py          # Stress testing
│   └── performance_config.py    # Performance targets
└── fixtures/                   # Test data and fixtures
    ├── sample_data.py           # Sample test data
    ├── mock_responses.py        # Mock service responses
    └── test_contracts/          # Sample Solidity contracts
```

### Features Implemented
- ✅ Comprehensive unit test suite with 90%+ code coverage
- ✅ Integration tests validating service-to-service communication
- ✅ End-to-end tests covering complete user workflows
- ✅ Performance tests establishing baseline metrics and load testing
- ✅ Security tests validating authentication, authorization, and data protection
- ✅ WebSocket integration tests for real-time communication
- ✅ Database integration tests with transaction and connection pool testing
- ✅ Error handling and recovery scenario testing
- ✅ CI/CD integration with automated test execution
- ✅ Test environment isolation and cleanup

## Acceptance Criteria

### Test Coverage and Quality
- [ ] Unit tests achieve 90%+ code coverage across all backend services
- [ ] Integration tests validate all service-to-service communication patterns
- [ ] End-to-end tests demonstrate complete workflow functionality from registration to analysis
- [ ] Test isolation ensures each test runs independently without side effects
- [ ] Test data setup and teardown maintains clean test environments

### Performance Validation
- [ ] Performance tests establish baseline response times under realistic load
- [ ] Load testing validates system handles 1000+ concurrent users
- [ ] API endpoints consistently respond under 100ms for 95th percentile
- [ ] Database operations complete within 50ms for standard queries
- [ ] WebSocket connections establish and maintain real-time communication

### Security Assurance
- [ ] Authentication tests validate JWT token security and expiration
- [ ] Authorization tests ensure RBAC properly enforced across all endpoints
- [ ] Data protection tests verify encryption and secure data handling
- [ ] Security scanning identifies and validates protection against common vulnerabilities
- [ ] Error handling tests confirm no sensitive information leakage

### Integration Reliability
- [ ] Service communication tests validate circuit breaker functionality
- [ ] Database transaction tests ensure ACID properties under concurrent load
- [ ] Real-time notification tests confirm WebSocket event delivery
- [ ] Error recovery tests demonstrate graceful degradation and recovery
- [ ] CI/CD pipeline automatically executes all test suites on code changes

This comprehensive testing strategy ensures robust validation of all backend services, providing confidence in system reliability, performance, and security while maintaining the local-first development approach that enables rapid testing and iteration.