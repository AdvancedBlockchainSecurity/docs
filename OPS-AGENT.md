# BlockSecOps Operations Agent Reference

> **Live index** for playbooks, pipelines, and workflows.
> This file does NOT duplicate content — it tells you WHERE to look.
> Always READ the source files for the latest information.
>
> Source directories:
> - `~/Git/docs/playbooks/` (46 files)
> - `~/Git/docs/pipelines/` (7 files)
> - `~/Git/docs/workflows/` (8 files)

---

## How to Use This Index

When answering questions about operations, pipelines, or workflows:

1. **Find the relevant file(s)** from the tables below
2. **Read the actual source file** — never rely on cached/memorized content
3. **Cross-reference** related files listed in each section

---

## Pipelines (~/Git/docs/pipelines/)

Technical documentation of data processing pipelines — stages, data models, database tables, error handling.

| File | Covers | Key Topics |
|------|--------|------------|
| `scan-execution-pipeline.md` | Multi-scanner execution orchestration | Trigger sources (dashboard/API/CLI), ScannerContext, scanner loop, K8s Jobs, 14 supported scanners, OrchestrationResult |
| `intelligence-pipeline.md` | Real-time per-scan enrichment (5 stages + dedup) | Normalization, fingerprinting (code/AST/location/fuzzy/semantic), pattern classification (BVD codes), FP prediction, enrichment, 5-level dedup matching |
| `fp-training-pipeline.md` | ML model training for false positive classification | Data collection (annotations/classifications/user_classification), 30+ feature extraction, RandomForest training, 80/20 split, model persistence (local/GCS), MIN_TRAINING_SAMPLES=50 |
| `deduplication-pipeline.md` | Daily background maintenance (2 AM UTC CronJob, 9 tasks) | Fingerprint repair, detector_id backfill, dedup group updates, canonical finding recalculation, dynamic scanner priorities, scanner quality metrics, pattern FP aggregates |
| `contract-upload-pipeline.md` | Contract upload, validation, storage | Auth (JWT/API key), name uniqueness, language detection (solidity/vyper/rust/move/cairo), multi-file support, framework detection (foundry/hardhat) |
| `scanner-upgrade-pipeline.md` | Scanner version upgrade procedure | Detector comparison, pattern seeding, audit validation, data safety guarantees, FP-heavy clean-slate procedure (16 steps), ML retrain trigger |
| `scanner-data-audit-pipeline.md` | 9-phase data integrity validation | Pre-flight checks, data inventory, ConfigMap version audit, fingerprint coverage, pattern mapping analysis, dedup group integrity, API endpoint validation, ML training data review, report generation |

### Pipeline Cross-References

- Scan execution triggers intelligence pipeline on completion
- Intelligence pipeline feeds deduplication pipeline
- FP training depends on labeled data from intelligence pipeline
- Scanner upgrade triggers deduplication maintenance
- Scanner data audit validates all pipeline outputs

---

## Workflows (~/Git/docs/workflows/)

End-to-end process documentation — phases, API endpoints, state machines, configuration, verification steps.

| File | Covers | Key Topics |
|------|--------|------------|
| `smart-contract-scanning-workflow.md` | Complete scan lifecycle (6 phases) | Upload, scan initiation, scanner execution (K8s Jobs), result processing (Celery), intelligence layer, storage/display. **37 API endpoints**, scanner reference (14 scanners with timeouts), scan presets (quick/standard/deep), quota/billing, scan state machine |
| `intelligence-pipeline-workflow.md` | 5-stage enrichment pipeline | Normalization → Fingerprinting → Pattern Classification → FP Prediction → Enrichment. 397 BVD patterns, 214+ pattern-tool mappings, seed scripts, ML model details |
| `deduplication-workflow.md` | 5-tier dedup matching strategy | EXACT (99%) / HIGH (95%) / MEDIUM (85%) / LOW (75%) / SEMANTIC (80%+). Intra-scan and cross-scan dedup phases, scanner priority ordering, DeduplicationGroupModel, known fingerprint issues, Feb 4 2026 audit fixes |
| `ml-training-workflow.md` | Random Forest FP classifier | 30+ features (scanner/code/pattern), training triggers (auto at 100 labels, manual admin), model evaluation metrics, prediction API, score interpretation (0-0.3 real, 0.3-0.6 uncertain, 0.6-1.0 FP), GCS storage |
| `scanner-upgrade-workflow.md` | 6-phase scanner upgrade | Version update, Docker image build, detector comparison, pattern seeding, audit/validation, dedup maintenance. Admin dashboard button, CLI scripts, verification commands, FP-heavy clean-slate procedure |
| `scan-timeout-retry-workflow.md` | Stale scan detection and recovery | Celery Beat check every 30s, `FOR UPDATE SKIP LOCKED` safety, auto-retry (3 retries), manual admin retry/force-fail, race condition prevention, GCP spot VM preemption handling |
| `stripe-dashboard-purchase-workflow.md` | Stripe payment testing | Publishable vs secret keys, pre-flight checklist, webhook forwarding, test card numbers (4242...), environment URLs (minikube/kubeadm/GCP), payment flow diagram |
| `README.md` | Workflow documentation overview | Standard document structure, list of active workflows |

### Workflow Cross-References

- Scanning workflow invokes intelligence pipeline workflow
- Intelligence pipeline workflow feeds into deduplication workflow
- ML training workflow depends on labels generated through scanning workflow
- Scanner upgrade workflow triggers deduplication maintenance
- Scan timeout/retry handles failures in scanning workflow

---

## Playbooks (~/Git/docs/playbooks/)

Step-by-step operational guides — prerequisites, UI + API methods, verification, troubleshooting.

### Admin Operations

| File | Covers | Key Topics |
|------|--------|------------|
| `admin-account-setup.md` | Create admin accounts, configure MFA | Admin creation, MFA enrollment, permissions |
| `admin-mfa-lockout-reset.md` | Reset MFA lockout | Failed attempt threshold, unlock procedure |
| `admin-session-management.md` | View, revoke, troubleshoot admin sessions | Session listing, revocation, audit trail |
| `admin-emergency-operations.md` | Emergency user disable, revoke access, incident response | Emergency procedures, access revocation |
| `admin-cli-commands.md` | All admin CLI commands | create-admin, list, reset-mfa, unlock-mfa, set-tier |

### Organization & Team Management

| File | Covers | Key Topics |
|------|--------|------------|
| `organization-team-setup.md` | Complete org/team/project setup guide | End-to-end setup, user access |
| `create-organization.md` | Enterprise org setup | Organization creation, configuration |
| `create-team.md` | Team creation and member management | Teams, membership |
| `create-project.md` | New scanning project setup | Project creation, contract association |
| `configure-roles.md` | RBAC setup | owner/admin/developer/auditor/guest roles |
| `invite-team-members.md` | Invite external users to org/team | Invitations, onboarding |

### Authentication & Wallet

| File | Covers | Key Topics |
|------|--------|------------|
| `connect-wallet.md` | MetaMask/WalletConnect SIWE authentication | Wallet connect, x402 payments |
| `link-wallet-to-account.md` | Add wallet to existing email account | Account linking |
| `api-key-management.md` | Create, scope, and rotate API keys | API key lifecycle, scopes |
| `security-configuration.md` | Security settings configuration | Security hardening |

### Scanning Operations

| File | Covers | Key Topics |
|------|--------|------------|
| `run-first-scan.md` | Upload contract and run first scan | Contract upload, scanner selection, results |
| `batch-scanning.md` | Scan multiple contracts at once | Batch operations, parallel scans |
| `schedule-scans.md` | Automated recurring scan scheduling | Cron-style scheduling, recurrence |
| `scan-stale-recovery.md` | Recover stale/stuck scans | Stale detection, retry, force-fail |

### CI/CD Integration

| File | Covers | Key Topics |
|------|--------|------------|
| `cicd-github-actions.md` | Scan on PR, block merge on critical findings | GitHub Actions workflow, PR gates |
| `cicd-gitlab-ci.md` | GitLab pipeline integration | .gitlab-ci.yml, pipeline stages |
| `cicd-jenkins.md` | Jenkins pipeline scanning | Jenkinsfile, plugin config |
| `cicd-webhook-generic.md` | Any CI system using webhooks + API | Generic webhook integration |

### ChatOps & Notifications

| File | Covers | Key Topics |
|------|--------|------------|
| `chatops-discord.md` | Discord webhook alerts | Discord bot/webhook setup, message format |
| `chatops-slack.md` | Slack notifications and alerts | Slack app, channels, message templates |
| `chatops-teams.md` | Teams channel notifications | Teams connector, adaptive cards |
| `notifications-email.md` | Email alert configuration | SMTP, templates, triggers |

### Issue Tracking Integration

| File | Covers | Key Topics |
|------|--------|------------|
| `integration-jira.md` | Create JIRA issues from vulnerabilities | JIRA API, issue mapping |
| `integration-github-issues.md` | Sync findings to GitHub Issues | GitHub API, issue creation |

### IDE Integration

| File | Covers | Key Topics |
|------|--------|------------|
| `ide-vscode.md` | VS Code extension setup | Extension install, configuration |
| `ide-jetbrains.md` | IntelliJ/WebStorm plugin setup | Plugin install, configuration |
| `cli-installation.md` | Apogee CLI install and configure | pip install, auth, commands |

### Deployment Operations

| File | Covers | Key Topics |
|------|--------|------------|
| `deploy-new-image.md` | Build, push, deploy Docker image | Docker build, Harbor push, kubectl apply |
| `admin-portal-deployment.md` | Admin portal deployment | Admin UI build and deploy |
| `upgrade-scanner-image.md` | Scanner image upgrade with dual versioning | Tool version + wrapper version, ConfigMap update |
| `docker-cleanup.md` | Safe Docker image/cache cleanup | Cleanup without affecting Harbor |

### Pricing & Billing

| File | Covers | Key Topics |
|------|--------|------------|
| `adjust-pricing.md` | Update pricing tiers, quotas, features, credit packages | Centralized tier config |
| `adjust-rate-limits.md` | Update endpoint-specific rate limits | Rate limit configuration |
| `stripe-payment-setup.md` | Stripe backend configuration | Secret keys, webhook setup |
| `stripe-test-subscriptions.md` | Stripe test mode subscriptions | Test cards, subscription lifecycle |
| `stripe-dashboard-purchase-playbook.md` | End-to-end Stripe purchase testing | Checkout flow, webhook verification |
| `website/update-pricing.md` | Update pricing on public website | Website pricing page |

### AI/ML Operations

| File | Covers | Key Topics |
|------|--------|------------|
| `ml-model-retraining.md` | Retrain false positive ML model | Training trigger, data requirements, verification |
| `ai-ml-audit-playbook.md` | Comprehensive AI/ML audit | Patterns, deduplication, ML endpoints, frontend components |
| `scanner-data-audit.md` | Scanner data integrity audit | 9-phase validation, health scores |

---

## Quick Lookup by Topic

Use this to find the right file(s) when asked about a topic:

| Topic | Read These Files |
|-------|-----------------|
| **"How does scanning work?"** | `workflows/smart-contract-scanning-workflow.md`, `pipelines/scan-execution-pipeline.md` |
| **"How does deduplication work?"** | `workflows/deduplication-workflow.md`, `pipelines/deduplication-pipeline.md` |
| **"How does the ML model work?"** | `workflows/ml-training-workflow.md`, `pipelines/fp-training-pipeline.md` |
| **"How to upgrade a scanner?"** | `workflows/scanner-upgrade-workflow.md`, `pipelines/scanner-upgrade-pipeline.md`, `playbooks/upgrade-scanner-image.md` |
| **"Scan is stuck/stale"** | `workflows/scan-timeout-retry-workflow.md`, `playbooks/scan-stale-recovery.md` |
| **"How does the intelligence pipeline work?"** | `workflows/intelligence-pipeline-workflow.md`, `pipelines/intelligence-pipeline.md` |
| **"How to set up Stripe?"** | `workflows/stripe-dashboard-purchase-workflow.md`, `playbooks/stripe-payment-setup.md`, `playbooks/stripe-test-subscriptions.md` |
| **"How to deploy a new image?"** | `playbooks/deploy-new-image.md`, `playbooks/docker-cleanup.md` |
| **"How to set up CI/CD scanning?"** | `playbooks/cicd-github-actions.md`, `playbooks/cicd-gitlab-ci.md`, `playbooks/cicd-jenkins.md` |
| **"How to manage admin accounts?"** | `playbooks/admin-account-setup.md`, `playbooks/admin-cli-commands.md`, `playbooks/admin-emergency-operations.md` |
| **"How to set up notifications?"** | `playbooks/chatops-slack.md`, `playbooks/chatops-discord.md`, `playbooks/chatops-teams.md`, `playbooks/notifications-email.md` |
| **"How to audit scanner data?"** | `pipelines/scanner-data-audit-pipeline.md`, `playbooks/scanner-data-audit.md` |
| **"How to upload a contract?"** | `pipelines/contract-upload-pipeline.md`, `playbooks/run-first-scan.md` |
| **"How to manage organizations/teams?"** | `playbooks/organization-team-setup.md`, `playbooks/create-organization.md`, `playbooks/create-team.md` |
| **"How to retrain the ML model?"** | `playbooks/ml-model-retraining.md`, `workflows/ml-training-workflow.md` |
| **"How to adjust pricing/tiers?"** | `playbooks/adjust-pricing.md`, `playbooks/adjust-rate-limits.md` |

---

## Related References

- **Infrastructure**: `~/Git/docs/INFRA-AGENT.md` — K8s cluster, GCP, resource allocation, monitoring
- **Standards**: `~/Git/docs/standards/INDEX.md` — Development rules, database management, versioning
- **CLAUDE.md**: `~/Git/docs/CLAUDE.md` — Agent registry, port reference, platform standards
