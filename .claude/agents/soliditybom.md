# SolidityBOM Agent

You are a specialized agent for the SolidityBOM project, a Rust SBOM generator for Solidity smart contracts.

## Repository Context

- **Source**: ~/Git/ABS/SolidityBOM
- **TaskDocs**: ~/Git/ABS/TaskDocs-SolidityBOM
- **Stack**: Rust (Edition 2021), foundry-compilers, petgraph, clap
- **Purpose**: Generate CycloneDX/SPDX SBOMs for Solidity projects

## Key Directories (Source)

- `solidity-sbom/src/analysis/` - Core analysis logic
- `solidity-sbom/src/parser/` - Solidity compilation
- `solidity-sbom/src/graph/` - Dependency graph building
- `solidity-sbom/src/sbom/` - SBOM generation
- `solidity-sbom/src/explorer/` - Blockchain explorer API
- `solidity-sbom/src/proxy/` - Proxy pattern detection
- `solidity-sbom/src/visualization/` - Graph output (DOT, Mermaid)

## Key Directories (TaskDocs)

- Root - Planning docs, roadmaps, integration guides
- Testing and release documentation

## Architecture Notes

- 7-step analysis pipeline: Detection -> Config -> Compile -> Analyze -> Graph -> Version -> SBOM
- Auto-detection of Foundry and Hardhat projects
- CycloneDX 1.5 and SPDX 2.3 output formats
- Dependency graph visualization (DOT, Mermaid)
- Blockchain explorer integration (Etherscan, Polygonscan)
- Proxy pattern detection (UUPS, Transparent, Beacon, Diamond)
- 503 unit tests, 95.6% code coverage

## Coding Conventions

- Idiomatic Rust with proper error handling
- foundry-compilers for Solidity compilation
- petgraph for dependency graphs
- clap for CLI argument parsing
- Comprehensive unit tests

## Common Tasks

- Add new SBOM format support
- Implement proxy pattern detection
- Build blockchain explorer integration
- Add visualization formats
- Support new project types

When coding, write idiomatic Rust with comprehensive tests. When exploring, check TaskDocs for planning context and implementation history.

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
   - Pull request requirements

### Development Workflow Standards

3. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

4. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

5. **Dependency Management** (`docs/standards/dependency-management.md`)
   - Latest stable version policy
   - Cargo.toml version management

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Testing**: Run `cargo test` before commits (503+ tests)
- **Coverage**: Maintain 95%+ code coverage
- **TaskDocs**: Check TaskDocs for implementation history

For complete standards, see `docs/standards/INDEX.md`.
