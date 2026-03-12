# Multi-Service GCP Audit & Deployment — 2026-03-12

## Summary
Comprehensive audit and deployment across 8 repositories following GCP migration. Fixed test failures, Prometheus annotations, authentication, tier gates, GCP cost optimization, and deployed all services.

## Services Updated

### Dashboard (0.46.24 → 0.46.27)
- **Authentication**: Removed Azure, Discord, Slack, BitBucket, Twitter OAuth providers. Kept Google + GitHub + Ethereum/Solana wallets
- **Registration**: Added Google/GitHub OAuth and Ethereum/Solana wallet signup options (previously email-only)
- **AuthContext**: Narrowed `loginWithOAuth` provider type to `'google' | 'github'`
- **Tier Gate Fixes**: Corrected 7 TierGate requiredTier mismatches to match API enforcement:
  - ApiKeys: developer → growth
  - Webhooks: starter → growth
  - AuditLogs: enterprise → growth
  - NotificationChannels: starter → growth
  - Users: starter → growth
  - Teams: enterprise → growth
  - Roles: enterprise → growth
- **Missing Tier Gates**: Added TierGate to 5 AI/monitoring pages:
  - CopilotPage (starter), CodeReviewPage (starter), CodeRepairPage (starter)
  - MonitoringPage (growth), IntelligenceDashboardPage (starter)
- **Version sync**: Updated all 4 kustomization.yaml files to match package.json

### API Service (0.29.80 → 0.29.81)
- Fixed stale docstring in organizations endpoint (starter → enterprise)
- Fixed semantic deduplicator test regex for intelligence-engine URL
- Synced all kustomization.yaml versions (local, production, gcp)

### Data Service (0.2.7 → 0.2.8)
- Fixed Prometheus annotation port: 8001 → 9090 (metrics endpoint)
- Reverted Service port back to 80 (callers use :80, targetPort handles routing)
- Version sync across all kustomization files

### Intelligence Engine (0.3.7 → 0.3.8)
- Fixed Prometheus annotation port: 8000 → 9090
- Version sync across all kustomization files

### Notification (0.2.6 → 0.2.7)
- Fixed Prometheus annotation port: 8003 → 9090
- Version sync across all kustomization files

### Orchestration (0.10.9 → 0.10.10)
- Updated scanner count test: 16 → 19 (added mythril, 4naly3er, foundry-fuzz)
- Updated unavailable scanners list
- Version sync across all kustomization files
- Built and pushed custom base image with 15+ security tools

### Contract Parser (no version change)
- Removed prometheus.io/* annotations (Rust service has no metrics endpoint)
- Fixed service-patch.yaml with $patch: replace to prevent duplicate port names

### GCP Infrastructure
- Cost optimization: default pool disk pd-ssd 100GB → pd-balanced 50GB
- Cost optimization: scanner pool disk pd-ssd → pd-balanced
- Reduced GKE logging: removed APISERVER, SCHEDULER, CONTROLLER_MANAGER components
- Estimated savings: ~$25-30/month

## Deployment Status
All services deployed to GKE cluster `apogee-production-gke` in `us-west1`.
