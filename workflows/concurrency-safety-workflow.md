# Concurrency Safety Workflow

**Last Updated:** February 19, 2026
**Status:** Active
**Applies to:** All Apogee platform services

---

## Overview

Decision workflow for selecting the correct concurrency safety pattern when fixing race conditions. Each platform language/framework has idiomatic patterns — this document maps race condition types to the right fix.

---

## Services Involved

| Service | Language | Async Model | Primary Patterns |
|---------|----------|-------------|-----------------|
| API Service | Python (FastAPI) | asyncio + SQLAlchemy async | Atomic SQL, FOR UPDATE, UPSERT |
| Orchestration | Python (Celery) | sync + SQLAlchemy sync | Atomic SQL, FOR UPDATE, async_to_sync |
| Tool Integration | Python (asyncio) | asyncio | asyncio.Lock, atomic file ops |
| Notification | Python (FastAPI) | asyncio + WebSocket | Snapshot iteration, asyncio.Lock |
| Dashboard | TypeScript (React) | Single-threaded + hooks | useRef, React Query, bounded collections |

---

## Decision Tree

### Step 1: Identify the Shared State

| State Type | Location | Go to Step |
|------------|----------|------------|
| Database row (single) | PostgreSQL | Step 2A |
| Database row (bulk) | PostgreSQL | Step 2B |
| In-memory collection | Python dict/set/list | Step 2C |
| In-memory singleton | Python class | Step 2D |
| File on disk | Local filesystem | Step 2E |
| React component state | Browser | Step 2F |
| External resource | Redis, Kubernetes API | Step 2G |

### Step 2A: Single Database Row

| Pattern | When to Use | SQLAlchemy |
|---------|-------------|------------|
| **Atomic UPDATE** | Counter increment/decrement, conditional set | `text("UPDATE ... SET col = col + 1 WHERE ... RETURNING ...")` |
| **UPSERT** | Insert-if-not-exists | `text("INSERT ... ON CONFLICT DO NOTHING")` |
| **SELECT FOR UPDATE** | Read-modify-write cycle | `.with_for_update()` |
| **Optimistic lock** | Rare conflicts, read-heavy | `UPDATE ... WHERE id = ? AND version = ?` |

**When to prefer FOR UPDATE over Atomic UPDATE:**
- The modification depends on reading multiple columns
- Business logic required between read and write
- Multiple tables must be read atomically

**When to prefer Atomic UPDATE over FOR UPDATE:**
- Simple counter operations (increment, decrement)
- Conditional set operations (SET x = y WHERE z > 0)
- Higher throughput needed (no lock wait)

### Step 2B: Bulk Database Operations

| Pattern | When to Use |
|---------|-------------|
| **Transaction wrapper** | All-or-nothing batch (delete, create, update) |
| **Bulk UPDATE** | Move rows between groups: `UPDATE ... WHERE group_id = ?` |
| **IntegrityError catch** | Unique constraint violations on concurrent inserts |

```python
# Transaction wrapper pattern
try:
    for item in items:
        db.add(item)
    await db.commit()
except Exception:
    await db.rollback()
    return ErrorResponse(success=False)
```

### Step 2C: In-Memory Collection (Python)

| Pattern | When to Use |
|---------|-------------|
| **asyncio.Lock** | Multiple coroutines access same dict/set/list |
| **Snapshot iteration** | Iterating collection that may be modified by another coroutine |
| **threading.Lock** | Multi-threaded access (Celery workers, class singletons) |

```python
# Snapshot iteration
for connection in list(self.active_connections):
    try:
        await connection.send_json(msg)
    except WebSocketDisconnect:
        self.active_connections.remove(connection)
```

### Step 2D: In-Memory Singleton (Python)

| Pattern | When to Use |
|---------|-------------|
| **threading.Lock** | Lazy-initialized class singleton |
| **module-level instance** | If initialization is cheap and side-effect-free |

### Step 2E: File on Disk

| Pattern | When to Use |
|---------|-------------|
| **Atomic write** (tempfile + rename) | Updating file content |
| **try/except FileNotFoundError** | Replacing existence checks |

```python
# Atomic write
import tempfile, os
fd, tmp_path = tempfile.mkstemp(dir=str(path.parent))
try:
    os.write(fd, new_content)
    os.close(fd)
    os.rename(tmp_path, str(path))
except Exception:
    os.close(fd)
    os.unlink(tmp_path)
    raise
```

### Step 2F: React Component State

| Pattern | When to Use |
|---------|-------------|
| **useRef** | Callback passed to subscribe/effect becomes stale |
| **React Query invalidation** | Multiple queries need coordinated refresh |
| **Bounded Set** | Dedup set or cache grows without bound |
| **Single init effect** | Multiple useEffects compete to initialize same state |

```typescript
// useRef for stable callback reference
const callbackRef = useRef(callback);
callbackRef.current = callback;

useEffect(() => {
    const unsub = subscribe((data) => callbackRef.current(data));
    return unsub;
}, [stableId]); // callback NOT in deps
```

### Step 2G: External Resource

| Pattern | When to Use |
|---------|-------------|
| **Redis LTRIM** | Bounding Redis lists after LPUSH |
| **ConfigMap resourceVersion** | Kubernetes optimistic concurrency |
| **asyncio.Lock around cache** | Preventing duplicate external API calls |

```python
# Redis list bounding
await redis.lpush("notifications", json.dumps(data))
await redis.ltrim("notifications", 0, 9999)  # Keep last 10,000
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|--------------|---------|-----|
| Read → Check → Write (separate queries) | TOCTOU — another request can modify between read and write | Atomic UPDATE or FOR UPDATE |
| `if not exists → create` | Duplicate insert on concurrent requests | UPSERT (ON CONFLICT) |
| `asyncio.run()` inside Celery | Creates new event loop, breaks async context | `async_to_sync` from asgiref |
| Iterating `dict.values()` while modifying | RuntimeError or skipped items | `list(dict.values())` snapshot |
| Unbounded `Set.add()` | Memory leak over long-running process | Bounded set with periodic eviction |
| Multiple useEffects initializing same state | Race between effects, localStorage thrashing | Single consolidated init effect |
| Stale closure in useEffect subscribe | Callback captures old state, ignores updates | useRef for latest callback |

---

## Celery-Specific Patterns

Celery workers run in separate processes with their own event loops:

| Scenario | Pattern |
|----------|---------|
| Calling async function from sync task | `async_to_sync(async_fn)()` from asgiref |
| Atomic counter in SQLAlchemy sync | `session.execute(update(Model).where(...).values(col=Model.col + 1))` |
| Job queue with FOR UPDATE | `.with_for_update(skip_locked=True)` to avoid blocking |

---

## React Query Patterns

| Scenario | Pattern |
|----------|---------|
| Mutation success → refresh list | `onSuccess: () => queryClient.invalidateQueries(['scans'])` |
| Polling active scan | `refetchInterval: 30000, refetchIntervalInBackground: false` |
| Optimistic update | `onMutate → setQueryData`, `onError → rollback` |

---

## Related Documentation

- [Race Condition Remediation Pipeline](../pipelines/race-condition-remediation-pipeline.md) — End-to-end fix pipeline
- [Race Condition Audit Playbook](../playbooks/race-condition-audit.md) — Audit checklist
- [Intelligence Integration Standards](../standards/INTELLIGENCE-INTEGRATION-STANDARDS.md) — Deduplication concurrency
