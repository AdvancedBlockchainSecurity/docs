# Task 1.5: Multi-Language Shared Library - Objectives & Implementation Details

## Repository: `solidity-security-shared`

**✅ ALIGNMENT CHECK**: This implementation aligns with Sprint 1 documentation requirements:
- Multi-language shared library (Rust core + Python/TypeScript bindings) ✓
- PyO3 bindings for Python-Rust integration ✓
- WASM bindings for TypeScript-Rust integration ✓
- Build systems and CI/CD workflow ✓
- Directory structure matches the documented requirements ✓

## High-Level Objectives

### Primary Goal
Create a foundational shared library that enables consistent types, utilities, and business logic across all Python, TypeScript, and Rust services in the platform.

### Key Requirements (from docs)
- **Rust Core Library**: Types, validation, crypto, constants, utilities
- **Python Bindings**: Pydantic schemas, authentication helpers, PyO3 integration
- **TypeScript Bindings**: Type definitions, validation schemas, WASM integration
- **Build Automation**: Makefile and CI/CD for cross-language builds
- **Testing**: Unit tests for all three language bindings

## Directory Structure Requirements

```
solidity-security-shared/
├── rust/                         # Core Rust library (37% performance boost)
├── python/                       # Python bindings (PyO3 integration)
├── typescript/                   # TypeScript bindings (WASM integration)  
├── wasm-bindings/               # Rust → WASM bridge
├── Makefile                     # Build automation
├── .github/workflows/           # CI/CD pipeline
└── README.md
```

## Step 1: Rust Core Library (4 hours)

### Objectives
- Create high-performance core types and utilities in Rust
- Implement serialization with Serde for cross-language compatibility
- Build validation, crypto, and utility modules
- Set up crate with both library and C-dynamic library outputs

### Key Components to Implement
- **Types Module**: Vulnerability, Finding, Analysis, Common types
- **Validation Module**: Input validation with custom error types
- **Crypto Module**: Hashing utilities, deterministic ID generation
- **Constants Module**: Severity weights, SWC mappings, status types
- **Utils Module**: Common utilities for all services

### Technical Requirements
- Configure `Cargo.toml` with `crate-type = ["cdylib", "rlib"]` for bindings
- Add feature flags for `python` and `wasm` optional dependencies
- Implement `Serde` serialization for all types
- Create comprehensive error types with `thiserror`
- Write unit tests for all modules

### Performance Goals
- Deterministic UUID generation from contract signatures
- Fast string hashing for vulnerability fingerprinting
- Efficient validation with zero-copy where possible

## Step 2: Python Bindings with PyO3 (2 hours)

### Objectives
- Create Python package that wraps Rust core functionality
- Implement Pydantic models that match Rust types exactly
- Build PyO3 bindings for performance-critical operations
- Provide fallback pure-Python implementations

### Key Components to Implement
- **Schemas Module**: Pydantic models (Vulnerability, Finding, Analysis)
- **Auth Module**: JWT utilities, permission helpers (per docs)
- **Constants Module**: Severity, status, SWC mappings (per docs)
- **Utils Module**: Validation helpers, crypto wrappers
- **Rust Bridge**: PyO3 bindings for core Rust functions

### Package Structure Requirements
- Use `src/solidity_shared/` package layout
- Create `setup.py` with PyO3 extension configuration
- Match exact directory structure from documentation
- Implement `__init__.py` with proper exports

### Integration Strategy
- Try to import Rust functions, fallback to pure Python
- Maintain API compatibility whether Rust bindings available or not
- Use `maturin` for building Python wheels with Rust extensions

## Step 3: TypeScript Bindings via WASM (1.5 hours)

### Objectives
- Create TypeScript package with Rust performance via WASM
- Implement Zod schemas for runtime validation
- Provide JavaScript fallbacks when WASM unavailable
- Build npm package with TypeScript definitions

### Key Components to Implement
- **Types Module**: TypeScript interfaces matching Rust types
- **Schemas Module**: Zod validation schemas
- **Utils Module**: Validation helpers, crypto utilities
- **WASM Integration**: Rust functions exposed via WASM
- **Fallbacks**: Pure JavaScript implementations

### WASM Bridge Requirements
- Separate `wasm-bindings` crate with `wasm-bindgen`
- Configure for bundler target output
- Implement `@wasm-bindgen` exports for key functions
- Handle serialization between JavaScript and Rust

### Build Strategy
- Use `wasm-pack build --target bundler`
- Output to `typescript/src/wasm/` directory
- Dynamic import with fallback error handling
- NPM package with both TypeScript source and compiled output

## Step 4: Build System with Makefile (0.5 hours)

### Objectives
- Create unified build system for all three languages
- Implement dependency management and installation
- Provide testing commands for all components
- Enable CI/CD integration

### Make Targets Required
- `install-deps`: Install Rust, Python, Node.js dependencies
- `build`: Build all three language packages
- `test`: Run all test suites
- `clean`: Remove build artifacts
- `dev-setup`: Complete development environment setup

### Build Dependencies
- Rust toolchain with `cargo`
- Python with `pip` and `maturin` for PyO3
- Node.js with `npm` for TypeScript
- `wasm-pack` for WASM generation

### CI/CD Integration
- GitHub Actions workflow file
- Test matrix for multiple Python/Node versions
- Artifact caching for faster builds
- Parallel job execution where possible

## Step 5: CI/CD Workflow (1 hour)

### Objectives
- Validate all three language implementations
- Run comprehensive test suites
- Check code formatting and linting
- Integration testing across languages

### Workflow Requirements
- **Rust Job**: Test, format check, clippy linting
- **Python Job**: Test across Python 3.8-3.11 matrix
- **TypeScript Job**: Build WASM, test, lint
- **Integration Job**: Cross-language compatibility test

### Quality Gates
- All unit tests must pass
- Code formatting must be consistent
- No clippy warnings in Rust
- TypeScript compilation without errors
- Integration tests validate cross-language type consistency

## Success Criteria & Validation

### Functional Requirements
- [ ] Shared library compiles in Rust, Python, TypeScript
- [ ] Cross-language bindings functional (PyO3 and WASM)
- [ ] All test suites passing
- [ ] Type consistency across all three languages
- [ ] Build system works on clean environment

### Performance Requirements
- [ ] Rust crypto functions significantly faster than pure Python/JS
- [ ] WASM bindings provide measurable performance improvement
- [ ] Memory usage reasonable for all implementations

### Integration Requirements
- [ ] Python services can import and use shared types
- [ ] TypeScript frontend can use shared validation
- [ ] Rust parser service can use shared types
- [ ] All packages use consistent semantic versioning

## Implementation Priority

### Phase 1 (Critical - 4 hours)
1. Rust core types and basic validation
2. Python Pydantic models with basic PyO3 bindings
3. TypeScript interfaces with basic WASM integration

### Phase 2 (Important - 2 hours) 
1. Complete crypto and utility functions
2. Full PyO3 bindings implementation
3. WASM optimization and error handling

### Phase 3 (Polish - 2 hours)
1. Comprehensive test suites
2. CI/CD workflow implementation
3. Documentation and README files

## Risk Mitigation

### Technical Risks
- **WASM Complexity**: Provide JavaScript fallbacks for all WASM functions
- **PyO3 Build Issues**: Include pure Python implementations as backup
- **Version Compatibility**: Pin dependency versions in all package files
- **Cross-Platform Builds**: Test on Linux/macOS/Windows in CI

### Development Risks
- **Time Overrun**: Prioritize basic type consistency over advanced features
- **Complexity Creep**: Focus only on types needed for Sprint 1
- **Integration Issues**: Test cross-language imports early and often

This foundation enables all subsequent Sprint 1 tasks by providing consistent, type-safe data structures and utilities across the entire platform.