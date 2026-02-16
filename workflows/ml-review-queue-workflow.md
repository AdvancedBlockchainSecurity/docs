# ML Review Queue Workflow

**Version:** 1.1.0
**Last Updated:** February 14, 2026

## Admin Workflow

**Note:** The Review Queue is an **admin-portal feature only** (`platform_admin` role required). It was moved from the main dashboard because active learning labeling is a platform administration task, not an end-user feature.

### 1. Open Review Queue
Navigate to **Review Queue** from the Admin Portal sidebar (requires `platform_admin` role).

### 2. Review Current Item
Each item shows:
- Vulnerability title and severity
- Scanner that found it
- ML prediction (false positive probability)
- Uncertainty score
- Code snippet

### 3. Label the Item
Choose one of:
- **Confirmed Real** (green) — The vulnerability is genuine
- **False Positive** (red) — This is not a real vulnerability
- **Skip** (gray) — Unsure, skip to next

Optionally adjust confidence (0-1) and add a reason.

### 4. Auto-Advance
After labeling, the next uncertain item loads automatically.

### 5. Impact
Labels feed into the ML training pipeline:
- Human labels have the highest weight
- More labels = better false positive detection
- Queue empties as model improves

## Labeling Guidelines

| Scenario | Label |
|----------|-------|
| Clear vulnerability with exploit path | Confirmed Real |
| Scanner false alarm (no actual risk) | False Positive |
| Depends on external context | Skip |
| Low severity but technically valid | Confirmed Real |
| Duplicate of another finding | False Positive |
