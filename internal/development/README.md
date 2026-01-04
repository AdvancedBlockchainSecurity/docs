# Development Guides

**Last Updated**: December 7, 2025
**Platform**: BlockSecOps Security Platform
**Tech Stack**: Python 3.11+, FastAPI, React TypeScript, Rust

---

## Overview

Comprehensive development guides for building and contributing to the BlockSecOps Platform. This directory covers everything from initial environment setup to advanced architecture patterns and CI/CD automation.

---

## Contents

### 🚀 Getting Started

Essential guides for new developers:

- **[Environment Setup](getting-started/environment-setup.md)** - Complete development environment configuration
  - Prerequisites (Python, Node.js, Rust, Docker, Kubernetes)
  - IDE setup (VSCode recommended)
  - Git workflow
  - Local cluster setup (Minikube)

- **[Build Systems](getting-started/build-systems.md)** - Build tools and workflows
  - Python build (Poetry)
  - Node.js build (npm/yarn)
  - Rust build (Cargo)
  - Docker builds
  - Multi-stage builds

---

### 🏗️ Architecture Patterns

Core architectural patterns used across the platform:

- **[DDD Implementation Guide](architecture-patterns/ddd-implementation-guide.md)** - Domain-Driven Design with complete examples
  - Domain layer structure
  - Entities and value objects
  - Domain services
  - Aggregates and repositories
  - Ubiquitous language

- **[CQRS Patterns](architecture-patterns/cqrs-patterns.md)** - Command Query Responsibility Segregation
  - Command handlers (write operations)
  - Query handlers (read operations)
  - Event sourcing basics
  - CQRS in FastAPI

- **[Testing DDD Services](architecture-patterns/testing-ddd-services.md)** - Testing strategies for DDD architecture
  - Unit testing domain logic
  - Integration testing repositories
  - Testing command handlers
  - Testing query handlers
  - Mocking external dependencies

---

### 🧪 Testing

Testing strategies and guides:

- **[Testing Guide](testing/testing-guide.md)** - Comprehensive testing documentation
  - Unit testing with pytest
  - Integration testing
  - E2E testing
  - Test coverage requirements (>80%)
  - CI test automation

- **[HttpOnly Cookie Testing](testing/httponly-cookie-testing.md)** - Testing cookie-based authentication
  - Legacy authentication testing (v0.1-v0.3)
  - Cookie verification
  - CORS testing
  - **Note**: Modern implementation uses Supabase Auth (Bearer tokens)

---

### 🔒 Security Tools

Advanced security testing tool guides:

- **[Echidna Fuzzing Guide](security-tools/echidna-fuzzing-guide.md)** - Property-based fuzzing for Solidity
  - Writing fuzz tests
  - Property assertions
  - Corpus management
  - Integration with scanner workflow

- **[Certora Formal Verification Guide](security-tools/certora-formal-verification-guide.md)** - Mathematical proof of correctness
  - CVL specification language
  - Writing verification rules
  - Proving contract properties
  - Interpreting results

- **[Manticore Symbolic Execution Guide](security-tools/manticore-symbolic-execution-guide.md)** - Symbolic analysis for Solidity
  - Symbolic execution basics
  - Path exploration
  - Constraint solving
  - Finding vulnerabilities

---

### ⚙️ Infrastructure

Infrastructure setup and management:

- **[AWS Terraform Setup Guide](infrastructure/aws-terraform-setup-guide.md)** - AWS infrastructure as code
  - EKS cluster setup
  - VPC configuration
  - RDS PostgreSQL
  - ElastiCache Redis
  - S3 buckets
  - IAM roles

- **[Dependency Management](infrastructure/dependency-management.md)** - Managing dependencies across languages
  - Python (Poetry, requirements.txt)
  - Node.js (package.json, npm/yarn)
  - Rust (Cargo.toml)
  - Vulnerability scanning
  - License compliance

- **[Dependency Monitoring Guide](infrastructure/dependency-monitoring-guide.md)** - Automated dependency tracking
  - Dependency monitoring service
  - Security vulnerability alerts
  - Automated updates
  - Dashboard integration

---

### 🔄 CI/CD

Continuous integration and deployment:

- **[CI/CD Automation](ci-cd/ci-cd-automation.md)** - Complete CI/CD pipeline documentation
  - GitHub Actions workflows
  - Docker image builds
  - Kubernetes deployments
  - Tag-based releases
  - ArgoCD GitOps

- **[Local GitHub Actions](ci-cd/local-github-actions.md)** - Test CI/CD locally
  - `act` tool setup
  - Running workflows locally
  - Debugging pipeline issues
  - Secrets management

- **[Plugin SDK Guide](ci-cd/plugin-sdk-guide.md)** - Custom scanner plugin development
  - Plugin architecture
  - Scanner SDK
  - Creating custom scanners
  - Publishing to registry

---

## Development Workflow

### Standard Development Flow

1. **Setup Environment**
   ```bash
   # Clone repository
   git clone https://github.com/yourusername/blocksecops-api-service.git
   cd blocksecops-api-service

   # Install dependencies
   poetry install

   # Start local infrastructure
   minikube start
   kubectl apply -k k8s/overlays/local
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feature/my-new-feature
   ```

3. **Make Changes**
   - Follow DDD patterns (see architecture-patterns/)
   - Write tests (see testing/)
   - Update documentation

4. **Test Locally**
   ```bash
   # Run unit tests
   poetry run pytest

   # Run integration tests
   poetry run pytest tests/integration

   # Check coverage
   poetry run pytest --cov=src --cov-report=html
   ```

5. **Commit Changes**
   ```bash
   git add .
   git commit -m "feat: add new feature"
   git push origin feature/my-new-feature
   ```

6. **Create Pull Request**
   - Automated CI runs tests
   - Code review required
   - Merge to main triggers deployment

---

## Code Quality Standards

### Python

- **Formatter**: `black` (line length 100)
- **Linter**: `ruff` (replaces flake8, pylint)
- **Type Checker**: `mypy --strict`
- **Import Sorter**: `isort`
- **Test Coverage**: >80% required

**Pre-commit hooks**:
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.10.0
    hooks:
      - id: black
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.3
    hooks:
      - id: ruff
```

### TypeScript

- **Formatter**: `prettier`
- **Linter**: `eslint`
- **Type Checker**: `tsc --noEmit`
- **Test Coverage**: >80% required

### Rust

- **Formatter**: `cargo fmt`
- **Linter**: `cargo clippy`
- **Test Coverage**: >80% required

---

## Related Documentation

### Architecture
- [API Service Architecture](../architecture/api-service-architecture.md)
- [Clean Architecture Decision](../architecture/clean-architecture-decision.md)
- [Authentication System](../architecture/authentication-system.md)

### Deployment
- [Local Development Setup](../local-development/README.md)
- [API Service Deployment](../deployment/api-service-deployment.md)
- [Docker Image Standards](../deployment/docker-image-standards.md)

### Testing
- [Testing Strategies](testing/testing-guide.md)
- [Integration Testing](testing/testing-ddd-services.md)

---

## Quick Reference

### Common Commands

```bash
# Run API service locally
poetry run uvicorn src.main:app --reload

# Run tests
poetry run pytest

# Format code
black src/ tests/
ruff check src/ tests/ --fix

# Type check
mypy src/

# Build Docker image
docker build -t api-service:dev .

# Deploy to local Kubernetes
kubectl apply -k k8s/overlays/local/api-service
```

### Environment Variables

```bash
# Required for local development
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/blocksecops"
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-anon-key"
export REDIS_URL="redis://localhost:6379"
```

---

## Contributing

### Pull Request Guidelines

1. **Branch naming**: `feature/`, `fix/`, `docs/`, `refactor/`
2. **Commit messages**: Follow [Conventional Commits](https://www.conventionalcommits.org/)
3. **Tests required**: All PRs must include tests
4. **Code review**: At least 1 approval required
5. **CI must pass**: All checks must be green

### Documentation Requirements

- Update README.md if adding new features
- Add docstrings to all public functions
- Include usage examples
- Update architecture diagrams if needed

---

**Maintained by**: BlockSecOps Development Team
**Last Review**: December 7, 2025
**Version**: 0.8.0 (Phase 3.4 Complete)
