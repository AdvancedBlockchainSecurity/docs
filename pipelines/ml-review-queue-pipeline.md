# ML Review Queue Pipeline

**Version:** 1.1.0
**Last Updated:** February 14, 2026
**Status:** Active

## Overview

The ML Review Queue implements an active learning loop for the false positive classifier. Uncertain predictions are surfaced for human review, improving model quality over time.

**Important:** The Review Queue labeling interface is **admin-portal only**. It was previously available in the main dashboard but has been moved to the admin portal since active learning labeling is a platform admin task, not an end-user feature.

## Architecture

```
Uncertainty Sampling → Review Queue Population → Human Labeling (Admin Portal)
    → Training Label Storage → Weighted Retraining → Improved Model
```

## Components

### Queue Population
- **Endpoint:** `POST /ml/populate-review-queue`
- **Source:** Vulnerabilities with ML uncertainty score > 0.3 and < 0.7
- **Strategy:** Uncertainty sampling (most uncertain predictions first)

### Labeling Workflow (Admin Portal Only)
- **Endpoint:** `POST /ml/review-queue/{vulnId}/label`
- **Labels:** "Confirmed Real" or "False Positive"
- **Metadata:** Confidence (0-1), reason text
- **Interface:** Admin Portal → Review Queue (`/review-queue`)
- **Access:** `platform_admin` role required

### Weak Label Generation
- **Endpoint:** `POST /ml/generate-weak-labels`
- **Sources:** Scanner consensus, severity heuristics, pattern matching
- **Weight:** Lower confidence than human labels

### Weighted Retraining
- **Endpoint:** `POST /admin/system/ml/retrain` (with `use_weights: true`)
- **Strategy:** Sample weights from label confidence
- **Human labels:** Weight 1.0
- **Weak labels:** Weight based on confidence (0.3-0.7)

## Integration Points

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Admin Portal | `/review-queue` page | Labeling interface (platform_admin only) |
| Admin Portal | ML Models page | Queue management, weak labels, retraining |
| API Service | `/ml/*` endpoints | Backend processing |

## Files

| Path | Repo | Purpose |
|------|------|---------|
| `src/presentation/api/v1/endpoints/ml.py` | api-service | Backend endpoints |
| `src/pages/AdminReviewQueue.tsx` | admin-portal | Dedicated review queue labeling page |
| `src/pages/AdminMLModels.tsx` | admin-portal | ML model management (populate queue, retrain) |
| `src/lib/api/admin.ts` | admin-portal | `getNextReviewItem`, `labelReviewItem` API methods |
| `src/layouts/AdminLayout.tsx` | admin-portal | Nav item (QueueListIcon, platform_admin role) |

## Admin Portal Review Queue Features

The dedicated Admin Portal review queue page provides:
- **Stats bar:** Total pending, total labeled, label balance (real vs false positive)
- **Current item card:** Vulnerability details, uncertainty score, ML prediction
- **Label buttons:** "Confirmed Real" (green), "False Positive" (red), "Skip" (gray)
- **Confidence slider:** 0-1, default 0.8
- **Reason text input:** Optional explanation for the label
- **Auto-advance:** Automatically loads next item after labeling
- **Queue management:** Populate queue button, stats refresh

---

**See Also:**
- [AI Features Workflow](../workflows/ai-features-workflow.md)
- [ML Training Workflow](../workflows/ml-training-workflow.md)
- [AI PoC Exploit Pipeline](./ai-poc-exploit-pipeline.md)
