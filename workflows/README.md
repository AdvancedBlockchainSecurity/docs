# Workflow Documentation

**Last Updated:** February 7, 2026

---

## Overview

This directory contains comprehensive documentation of key workflows in the BlockSecOps platform. Each document provides end-to-end coverage of a specific operational flow, including architecture diagrams, service interactions, data models, and API references.

---

## Workflow Documentation Structure

Each workflow document follows a standard structure:

1. **Overview** - High-level architecture diagram and summary
2. **Services Involved** - Table of participating services and their roles
3. **Workflow Phases** - Detailed step-by-step flow with diagrams
4. **Data Models** - Key database schemas and relationships
5. **API Endpoints** - Relevant endpoints for each phase
6. **State Machines** - Status transitions and lifecycle
7. **Configuration** - Environment variables and ConfigMaps
8. **Related Documentation** - Links to detailed component docs

---

## Quick Reference

### Smart Contract Scanning Workflow

**Key Services:**
- API Service - HTTP gateway for contract/scan operations
- Orchestration Service - Celery-based workflow management
- Tool Integration Service - Kubernetes Job execution for scanners
- Intelligence Engine - Deduplication and classification
- Dashboard - React UI for results display

**Supported Languages:**
- Solidity (11 scanners)
- Vyper (2 scanners)
- Solana/Rust (4 scanners - pending)

**Scan Flow:**
```
Upload → Validate → Queue → Execute Scanners → Process Results → Display
```

---

## Contributing

When adding new workflow documentation:

1. Follow the standard structure outlined above
2. Include architecture diagrams (text-based ASCII art preferred)
3. Document all API endpoints with request/response examples
4. Include state machine diagrams for status transitions
5. Link to related component documentation
6. Update this README with the new workflow

---

## Related Documentation

- [Scanner Documentation](../scanners/README.md) - Individual scanner guides
- [API Documentation](../api/README.md) - Complete API reference
- [Architecture Documentation](../architecture/) - System architecture
- [Standards](../standards/) - Development standards and guidelines

---

**Maintained by:** BlockSecOps Platform Team
