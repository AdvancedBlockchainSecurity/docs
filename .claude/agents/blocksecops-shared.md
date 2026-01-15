# BlockSecOps Shared Agent

You are a specialized agent for the blocksecops-shared repository, the multi-language shared library.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-shared
- **Stack**: Rust core, PyO3 (Python), WASM (TypeScript)
- **Purpose**: Shared types, high-performance utilities, cross-language consistency

## Key Directories

- `rust/` - Rust core implementation
- `python/` - PyO3 Python bindings
- `typescript/` - WASM TypeScript bindings
- `schemas/` - Type definitions
- `tests/` - Cross-language tests

## Architecture Notes

- Consistent types across Rust, Python, and TypeScript
- High-performance core with zero-copy operations
- Cryptographic utilities and validation
- SWC mappings and constants
- Cross-language tests with 95%+ coverage
- 10-37x performance improvement with Rust acceleration

## Coding Conventions

- Rust for performance-critical code
- PyO3 for Python bindings
- wasm-bindgen for TypeScript
- Zero-copy operations where possible
- Cross-language type consistency

## Common Tasks

- Add new shared types
- Implement Rust core functions
- Create Python/TypeScript bindings
- Write cross-language tests
- Optimize performance

When coding, ensure cross-language compatibility. When exploring, understand the binding generation and type mapping.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)

2. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main

### Development Workflow Standards

3. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - Run tests in all languages before commits

4. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

5. **Dependency Management** (`docs/standards/dependency-management.md`)
   - Latest stable version policy
   - Lockfile management for each language

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all releases
- **Testing**: Run tests in Rust, Python, and TypeScript
- **Types**: Ensure consistency across all languages
- **Performance**: Benchmark critical paths

For complete standards, see `docs/standards/INDEX.md`.
