# SolidityDefend Agent

You are a specialized agent for the SolidityDefend project, a Rust SAST scanner for Solidity smart contracts.

## Repository Context

- **Source**: ~/Git/ABS/SolidityDefend
- **TaskDocs**: ~/Git/ABS/TaskDocs-SolidityDefend
- **Stack**: Rust 1.82+, solang-parser, salsa, bumpalo, petgraph, rayon
- **Purpose**: Security vulnerability detection with 287+ detectors

## Key Directories (Source)

- `crates/parser/` - Solidity parsing (solang-parser)
- `crates/ast/` - Arena-allocated AST (bumpalo)
- `crates/semantic/` - Type resolution, symbols
- `crates/cfg/` - Control flow graph
- `crates/dataflow/` - Data flow analysis
- `crates/detectors/` - 287+ security detectors
- `crates/analysis/` - Core analysis engine
- `crates/lsp/` - Language Server Protocol
- `crates/cli/` - Command-line interface

## Key Directories (TaskDocs)

- Root - 39+ phase implementation plans
- `analysis/` - Detector designs, FP analysis, confidence scoring

## Architecture Notes

- 18-crate modular workspace design
- 287+ security detectors (OWASP 2025 aligned)
- Salsa-based incremental computation
- Arena-allocated AST with bumpalo
- CFG and DFG construction with petgraph
- Parallel analysis with rayon
- LSP server for IDE integration
- Multiple output formats: Console, JSON, SARIF
- <1-10 second analysis time

## Coding Conventions

- 18-crate modular architecture
- Salsa for incremental computation
- Arena allocation for AST nodes
- Parallel analysis with rayon
- Detector pattern with confidence scoring

## Common Tasks

- Implement new security detectors
- Add analysis passes (CFG, DFG)
- Build LSP features
- Optimize performance
- Reduce false positives

When coding, follow the modular crate architecture. When exploring, check TaskDocs for detector designs and implementation phases.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)

2. **Intelligence Integration Standards** (`docs/standards/INTELLIGENCE-INTEGRATION-STANDARDS.md`)
   - Vulnerability pattern classification (BVD codes)
   - Fingerprinting strategies
   - Deduplication algorithms
   - Detector-to-pattern mappings

3. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main
   - Pull request requirements

### Development Workflow Standards

4. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

5. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

6. **Dependency Management** (`docs/standards/dependency-management.md`)
   - Latest stable version policy
   - Cargo.toml version management

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Testing**: Run `cargo test` before commits
- **Architecture**: Follow 18-crate modular design
- **Detectors**: Use confidence scoring pattern
- **TaskDocs**: Check TaskDocs for implementation phases

For complete standards, see `docs/standards/INDEX.md`.
