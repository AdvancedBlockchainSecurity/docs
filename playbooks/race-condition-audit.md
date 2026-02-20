# Playbook: Race Condition Audit

**Version:** 1.0.0
**Last Updated:** February 19, 2026

## Overview

Step-by-step checklist for auditing a BlockSecOps service for race conditions. Use this playbook during quarterly concurrency audits or when investigating concurrency bugs.

---

## Prerequisites

- [ ] Read access to the service repository
- [ ] Understanding of the service's async model (asyncio, threading, React hooks)
- [ ] Familiarity with [Concurrency Safety Workflow](../workflows/concurrency-safety-workflow.md)

---

## Audit Checklist

### Phase 1: Database Race Conditions

#### 1.1 Check-Then-Act (TOCTOU)

Search for patterns where a database read is followed by a conditional write:

```bash
# Look for "if not found → create" patterns
grep -rn "is None" --include="*.py" src/ | grep -i "create\|insert\|add"

# Look for balance/quota checks before deduction
grep -rn "balance\|quota\|credit\|limit" --include="*.py" src/ | grep -i "check\|verify\|enough\|sufficient"
```

**Red flags:**
- [ ] `if user is None: create_user(...)` — needs UPSERT
- [ ] `if balance >= cost: deduct(cost)` — needs atomic UPDATE with WHERE clause
- [ ] `count = get_active_scans(); if count < limit:` — needs FOR UPDATE

#### 1.2 Non-Atomic Counter Updates

Search for ORM-level counter increments:

```bash
# Look for attribute assignment that should be atomic
grep -rn "\.count\s*=\|\.size\s*=\|\.retry_count\s*=" --include="*.py" src/
grep -rn "or 0) + 1\|or 1) + 1" --include="*.py" src/
```

**Red flags:**
- [ ] `model.count = model.count + 1` — needs `UPDATE ... SET count = count + 1`
- [ ] `model.retry_count = (model.retry_count or 0) + 1` — needs atomic SQL

#### 1.3 Missing Row Locks

Search for read-modify-write patterns without FOR UPDATE:

```bash
# Look for status transitions
grep -rn "\.status\s*=" --include="*.py" src/ | grep -v "==\|!="
```

**Red flags:**
- [ ] Read vulnerability → update status → commit (without FOR UPDATE)
- [ ] Read scan → update progress → commit (without FOR UPDATE)

#### 1.4 Bulk Operations Without Transaction Safety

```bash
# Look for loops with individual commits
grep -rn "for.*in.*:" --include="*.py" -A5 src/ | grep "commit\|flush"

# Look for batch deletes/updates
grep -rn "batch\|bulk" --include="*.py" src/
```

**Red flags:**
- [ ] Bulk delete without try/except around commit
- [ ] Loop with commit inside (partial failure leaves inconsistent state)

---

### Phase 2: Application Memory Race Conditions

#### 2.1 Shared Collections (Python)

```bash
# Look for module-level or class-level mutable state
grep -rn "^[a-z_]*:\s*dict\|^[a-z_]*:\s*list\|^[a-z_]*:\s*set" --include="*.py" src/
grep -rn "self\.\w*connections\|self\.\w*cache\|self\.\w*jobs" --include="*.py" src/
```

**Red flags:**
- [ ] `self.active_connections: list` modified from multiple coroutines without lock
- [ ] Dict/set iterated in one coroutine, modified in another
- [ ] Module-level cache without asyncio.Lock

#### 2.2 Singleton Initialization

```bash
grep -rn "_instance\s*=\s*None\|cls\._instance" --include="*.py" src/
```

**Red flags:**
- [ ] Lazy singleton without threading.Lock (if accessed from multiple threads)

#### 2.3 Event Loop Mixing

```bash
grep -rn "asyncio\.run\b" --include="*.py" src/
```

**Red flags:**
- [ ] `asyncio.run()` inside Celery task — needs `async_to_sync` from asgiref
- [ ] `asyncio.run()` when an event loop is already running

---

### Phase 3: Frontend Race Conditions (React/TypeScript)

#### 3.1 Stale Closures in Effects

```bash
# Look for callbacks in useEffect dependency arrays
grep -rn "useEffect.*\[.*callback\|useEffect.*\[.*on[A-Z]" --include="*.ts" --include="*.tsx" src/
```

**Red flags:**
- [ ] `useEffect(() => { subscribe(onCompleted) }, [scanId, onCompleted])` — onCompleted causes re-subscribe on every render

#### 3.2 Competing useEffects

```bash
# Count useEffect calls per file
for f in $(find src -name "*.tsx" -o -name "*.ts"); do
  count=$(grep -c "useEffect" "$f" 2>/dev/null)
  if [ "$count" -gt 3 ]; then echo "$f: $count useEffects"; fi
done
```

**Red flags:**
- [ ] Multiple useEffects writing to the same state variable
- [ ] Multiple useEffects reading/writing localStorage for the same key

#### 3.3 Unbounded Collections

```bash
grep -rn "useRef.*new Set\|useRef.*new Map\|useRef.*\[\]" --include="*.ts" --include="*.tsx" src/
```

**Red flags:**
- [ ] Dedup Set that grows without bound
- [ ] Cache Map without eviction strategy

#### 3.4 Token Refresh Races

```bash
grep -rn "refreshSession\|refreshToken\|401" --include="*.ts" src/
```

**Red flags:**
- [ ] Multiple concurrent 401s triggering parallel token refreshes

---

### Phase 4: External Resource Race Conditions

#### 4.1 Kubernetes API

```bash
grep -rn "patch_namespaced\|replace_namespaced" --include="*.py" src/
```

**Red flags:**
- [ ] ConfigMap/Secret update without resourceVersion check (optimistic concurrency)

#### 4.2 Redis Operations

```bash
grep -rn "lpush\|rpush\|sadd" --include="*.py" src/
```

**Red flags:**
- [ ] LPUSH without LTRIM → unbounded list growth

#### 4.3 File Operations

```bash
grep -rn "\.exists()\|path\.is_file()" --include="*.py" src/
```

**Red flags:**
- [ ] `if path.exists(): read(path)` — file could be deleted between check and read
- [ ] Writing file without atomic rename

---

## Severity Assessment

| Finding | Severity | Justification |
|---------|----------|---------------|
| Credit/payment race | CRITICAL | Financial impact |
| User creation duplicate | CRITICAL | Auth system corruption |
| Scan status lost update | HIGH | Incorrect scan results |
| Counter drift | HIGH | Inaccurate metrics |
| WebSocket broadcast crash | HIGH | Service disruption |
| UI stale closure | MEDIUM | Incorrect behavior |
| Memory leak (unbounded set) | MEDIUM | Gradual degradation |
| File TOCTOU | MEDIUM | Rare in practice |

---

## Reporting Template

For each finding, document:

```markdown
### RC-FIX-NNN: <Short Title>

**Severity:** CRITICAL | HIGH | MEDIUM
**Service:** <service-name>
**File:** `<path/to/file.py>` (lines ~X-Y)
**Race Type:** TOCTOU | Lost Update | Duplicate Insert | Stale Closure | Iteration Mutation | Unbounded Growth
**Pattern Applied:** Atomic SQL | UPSERT | FOR UPDATE | asyncio.Lock | useRef | Snapshot Copy | Bounded Set
**Description:** <What the race condition is and how it manifests>
**Fix:** <What was changed>
```

---

## Reference: All Fixes from February 2026 Audit

46 race conditions identified and fixed across 5 services:

| Service | Fixes | Version Bump |
|---------|-------|-------------|
| API Service | RC-FIX-001 through RC-FIX-011 | 0.28.54 → 0.29.0 |
| Dashboard | RC-FIX-012 through RC-FIX-021 | 0.45.15 → 0.46.0 |
| Orchestration | RC-FIX-022 through RC-FIX-029 | 0.9.16 → 0.10.0 |
| Tool Integration | RC-FIX-030 through RC-FIX-038, RC-FIX-046 | 0.4.8 → 0.5.0 |
| Notification | RC-FIX-039 through RC-FIX-044 | 0.1.2 → 0.2.0 |

### Key Fixes by Pattern

| Pattern | Fix IDs |
|---------|---------|
| Atomic SQL UPDATE | 1, 3, 9, 22, 27 |
| UPSERT (ON CONFLICT) | 2 |
| SELECT FOR UPDATE | 6, 7, 26, 29 |
| Transaction wrapper | 8, 10 |
| IntegrityError catch | 5 |
| asyncio.Lock | 33, 35, 37 |
| threading.Lock | 28 |
| async_to_sync | 23, 24 |
| useRef | 13 |
| Consolidated useEffect | 14 |
| Token refresh mutex | 15 |
| Snapshot iteration | 39, 40 |
| Bounded collection | 21, 43 |
| Atomic file write | 46 |
| Optimistic concurrency | 38 |
| Grace period / status check | 31, 32, 34 |
| Auth state machine | 41, 42, 44 |

---

## Related Documentation

- [Race Condition Remediation Pipeline](../pipelines/race-condition-remediation-pipeline.md) — End-to-end fix pipeline
- [Concurrency Safety Workflow](../workflows/concurrency-safety-workflow.md) — Pattern selection decision tree
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Version table with current versions
