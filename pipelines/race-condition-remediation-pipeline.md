# Race Condition Remediation Pipeline

Standard approach for identifying, classifying, and fixing race conditions across the Apogee platform. Covers atomic SQL patterns, UPSERT, SELECT FOR UPDATE, optimistic locking, and async locks.

## Overview

```
Audit Phase                    Fix Phase                         Verification Phase
─────────────                  ──────────                        ──────────────────
1. Identify shared state       4. Classify race type             7. Code compiles/lints
2. Trace concurrent access     5. Select fix pattern             8. Existing tests pass
3. Assess severity             6. Implement fix                  9. Version bump + kustomization
                                                                 10. Feature branch per VCS standards
```

## Trigger

- **Scheduled**: Quarterly concurrency audit
- **Reactive**: Bug report involving duplicate records, lost updates, or inconsistent state
- **Pre-release**: Before any MAJOR version bump

---

## Pipeline Steps

| # | Step | Description |
|---|------|-------------|
| 1 | Identify shared state | Find mutable state accessed by concurrent requests (DB rows, in-memory collections, files) |
| 2 | Trace concurrent access | Map code paths that read-then-write the same state (API endpoints, background tasks, WebSocket handlers) |
| 3 | Assess severity | CRITICAL: data corruption/financial. HIGH: duplicate records. MEDIUM: inconsistent UI state |
| 4 | Classify race type | TOCTOU, lost update, duplicate insert, stale closure, iteration mutation, unbounded growth |
| 5 | Select fix pattern | See **Fix Pattern Decision Tree** below |
| 6 | Implement fix | Apply the selected pattern with minimal blast radius |
| 7 | Verify | Compile, lint, run existing tests, confirm no regressions |
| 8 | Version bump | MINOR bump (new safety feature, backwards-compatible) |
| 9 | Update kustomization | Match `newTag` and `app.kubernetes.io/version` to new version |
| 10 | Document | Record fix ID, affected file, pattern used, severity |

---

## Fix Pattern Decision Tree

```
Is the race in a database operation?
├── YES: Is it a read-then-write on the same row?
│   ├── YES: Does it increment/decrement a counter?
│   │   └── Use ATOMIC SQL UPDATE (Pattern A)
│   ├── YES: Does it check existence before insert?
│   │   └── Use UPSERT / ON CONFLICT (Pattern B)
│   └── YES: Does it read, modify, then write back?
│       └── Use SELECT ... FOR UPDATE (Pattern C)
├── YES: Is it a bulk operation that must be all-or-nothing?
│   └── Use TRANSACTION WRAPPER with rollback handling (Pattern D)
└── NO: Is the race in application memory?
    ├── Python async? → Use asyncio.Lock (Pattern E)
    ├── Python threaded? → Use threading.Lock (Pattern F)
    ├── React hook stale closure? → Use useRef (Pattern G)
    ├── Collection modified during iteration? → Use snapshot copy (Pattern H)
    └── Unbounded growth? → Use bounded collection with eviction (Pattern I)
```

---

## Fix Patterns

### Pattern A: Atomic SQL UPDATE

**Use when:** Incrementing/decrementing counters, conditional updates.

```sql
-- Instead of: SELECT balance → check → UPDATE balance
UPDATE scan_credits
SET balance = balance - 1
WHERE user_id = :user_id AND balance >= 1
RETURNING balance;
```

**SQLAlchemy:**
```python
from sqlalchemy import text
result = await db.execute(
    text("UPDATE scan_credits SET balance = balance - 1 "
         "WHERE user_id = :user_id AND balance >= 1 "
         "RETURNING balance"),
    {"user_id": user_id}
)
row = result.fetchone()
if row is None:
    raise HTTPException(status_code=402, detail="Insufficient credits")
```

### Pattern B: UPSERT (INSERT ... ON CONFLICT)

**Use when:** Check-then-create patterns where duplicates are possible.

```sql
INSERT INTO users (supabase_user_id, email, created_at)
VALUES (:sub, :email, NOW())
ON CONFLICT (supabase_user_id) DO NOTHING;

-- Always follow with SELECT to get the row
SELECT * FROM users WHERE supabase_user_id = :sub;
```

### Pattern C: SELECT ... FOR UPDATE

**Use when:** Read-modify-write on existing rows.

```python
# SQLAlchemy
stmt = select(VulnerabilityModel).where(
    VulnerabilityModel.id == vuln_id
).with_for_update()
result = await db.execute(stmt)
vuln = result.scalar_one_or_none()
```

**Variant — skip locked (for job queues):**
```python
stmt = select(ScanModel).where(
    ScanModel.status == "queued"
).with_for_update(skip_locked=True).limit(1)
```

### Pattern D: Transaction Wrapper

**Use when:** Bulk operations that must succeed or fail atomically.

```python
try:
    # ... bulk operations ...
    await db.commit()
except Exception as e:
    await db.rollback()
    logger.error(f"Bulk operation failed: {e}")
    return ErrorResponse(success=False, detail="Operation rolled back")
```

### Pattern E: asyncio.Lock

**Use when:** Protecting shared async state in Python.

```python
import asyncio

_lock = asyncio.Lock()

async def protected_operation():
    async with _lock:
        # ... read and modify shared state ...
```

### Pattern F: threading.Lock

**Use when:** Protecting shared state in threaded Python (singletons, class methods).

```python
import threading

class EnrichmentService:
    _lock: threading.Lock = threading.Lock()
    _instance = None

    @classmethod
    def get_service(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = cls()
            return cls._instance
```

### Pattern G: useRef for Stale Closures

**Use when:** React callback references become stale in useEffect/subscribe.

```typescript
const onCompletedRef = useRef(onCompleted);
onCompletedRef.current = onCompleted;

useEffect(() => {
    const unsub = wsManager.subscribe('scan_completed', (data) => {
        onCompletedRef.current?.(data);  // Always uses latest
    });
    return () => unsub();
}, [scanId]);  // onCompleted removed from deps
```

### Pattern H: Snapshot Copy

**Use when:** Iterating a collection that may be modified concurrently.

```python
# Instead of: for conn in self.active_connections:
for conn in list(self.active_connections):  # Snapshot
    await conn.send_json(message)
```

### Pattern I: Bounded Collection

**Use when:** Sets/lists grow without bound over time.

```typescript
useEffect(() => {
    const checkAndEvict = () => {
        if (shownNotifications.current.size > 200) {
            const entries = Array.from(shownNotifications.current);
            shownNotifications.current = new Set(entries.slice(-100));
        }
    };
    const interval = setInterval(checkAndEvict, 30000);
    return () => clearInterval(interval);
}, []);
```

---

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|---------|
| CRITICAL | Data corruption, financial impact, security bypass | Credit double-spend, duplicate user creation |
| HIGH | Duplicate records, lost updates, incorrect counts | Dedup counter drift, concurrent scan limit bypass |
| MEDIUM | UI inconsistency, memory leaks, degraded UX | Stale closures, unbounded notification sets |

---

## Version Bump Convention

Race condition fixes are **MINOR** bumps (new safety features, backwards-compatible):

```
0.28.54 → 0.29.0  (not 0.28.55)
```

All version references must be updated together:
1. Source file (`pyproject.toml` or `package.json`)
2. Kustomization `newTag`
3. Kustomization `app.kubernetes.io/version` label
4. `docs/standards/docker-image-versioning.md` version table

---

## Related Documentation

- [Concurrency Safety Workflow](../workflows/concurrency-safety-workflow.md) — Decision tree for selecting patterns
- [Race Condition Audit Playbook](../playbooks/race-condition-audit.md) — Step-by-step audit checklist
- [Docker Image Versioning](../standards/docker-image-versioning.md) — Version bump standards
