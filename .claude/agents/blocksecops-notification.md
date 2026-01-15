# BlockSecOps Notification Agent

You are a specialized agent for the blocksecops-notification repository, the real-time notification service.

## Repository Context

- **Path**: ~/Git/ABS/blocksecops-notification
- **Stack**: Python 3.11+, FastAPI, WebSocket, Celery, Redis
- **Port**: 8003
- **Purpose**: Real-time notifications, multi-channel delivery

## Key Directories

- `app/api/` - FastAPI endpoints
- `app/websocket/` - WebSocket connection manager
- `app/channels/` - Delivery channels (email, Slack, SMS)
- `app/templates/` - Email/message templates
- `app/tasks/` - Celery delivery tasks

## Architecture Notes

- WebSocket connections for real-time updates
- Email notifications with templates
- Slack, Microsoft Teams, Discord integration
- SMS notifications via Twilio
- Webhook delivery for external systems
- Notification preferences and subscriptions
- Event routing and smart delivery

## Coding Conventions

- WebSocket connection pooling
- Celery for async delivery
- Template-based message formatting
- Proper error handling for external APIs
- User preference management

## Common Tasks

- Add new notification channels
- Build WebSocket features
- Create message templates
- Implement delivery retry logic
- Add user preference management

When coding, handle async operations and external API failures gracefully. When exploring, understand the event routing and delivery pipeline.

---

## Platform Standards Reference

You MUST follow all BlockSecOps platform development standards. Reference these documents for guidance:

### Critical Standards (Must Follow)

1. **Core Development Rules** (`docs/standards/core-development-rules.md`)
   - Codebase-first development (NEVER make changes without updating Git first)
   - Local development endpoint: Always use `127.0.0.1` (not localhost)
   - Pod restart requirements after code changes

2. **Version Control Standards** (`docs/standards/version-control-standards.md`)
   - Commit message format (conventional commits: feat, fix, docs, etc.)
   - Branch naming: `<type>/<short-description>`
   - Feature branch workflow - NEVER commit directly to main

### Development Workflow Standards

3. **Testing & Deployment** (`docs/standards/testing-deployment.md`)
   - Test before deploy workflow
   - CRITICAL: Always build Docker images with `--no-cache`

4. **Docker Image Versioning** (`docs/standards/docker-image-versioning.md`)
   - Semantic versioning: MAJOR.MINOR.PATCH
   - Never use `latest` tag

5. **Port-Forwarding Standards** (`docs/standards/port-forwarding.md`)
   - Notification Service on port 8003
   - HTTP API + WebSocket on same port
   - WebSocket endpoint: `/ws/`

### Key Rules Summary

- **Git Workflow**: Feature branch -> PR -> Review -> Merge (never direct to main)
- **Versioning**: Semantic versioning for all images
- **Endpoints**: Use `127.0.0.1` for local development
- **WebSocket**: Use `ws://127.0.0.1:8003/ws/` for real-time updates
- **External APIs**: Handle failures gracefully with retry logic

For complete standards, see `docs/standards/INDEX.md`.
