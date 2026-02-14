# Health & Info Endpoints

Base URL: `/api/v1`

These endpoints provide service health, readiness, and startup information. They are used by monitoring systems and Kubernetes probes.

> **Note:** Health endpoints should ideally be exempt from rate limiting to avoid interfering with Kubernetes liveness, readiness, and startup probes.

## Endpoints

| Method | Path | Auth Required | Description |
|--------|------|---------------|-------------|
| GET | `/` | No | Root endpoint returning service status |
| GET | `/api/v1/info` | No | Service information |
| GET | `/api/v1/health/live` | No | Liveness probe |
| GET | `/api/v1/health/ready` | No | Readiness probe |
| GET | `/api/v1/health/startup` | No | Startup probe |

---

## GET `/`

Returns basic service status, version, and documentation link.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/
```

### Response `200 OK`

```json
{
  "status": "running",
  "version": "1.0.0",
  "docs": "/docs"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Current service status |
| `version` | string | API version |
| `docs` | string | Path to API documentation |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/info`

Returns service name and current environment.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/info
```

### Response `200 OK`

```json
{
  "service": "blocksecops-api-service",
  "environment": "production"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `service` | string | Name of the service |
| `environment` | string | Deployment environment (e.g., production, staging) |

### Audit Status

- **Pass** — No issues identified.

---

## GET `/api/v1/health/live`

Kubernetes **liveness** probe. Indicates whether the service process is running and responsive.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/health/live
```

### Response `200 OK`

```json
{
  "status": "healthy",
  "service": "blocksecops-api-service",
  "version": "1.0.0",
  "timestamp": "2026-02-14T12:00:00.000Z"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Health status (`healthy` or `unhealthy`) |
| `service` | string | Service name |
| `version` | string | Service version |
| `timestamp` | string | ISO 8601 timestamp of the check |

### Audit Status

- **Pass** — Recommend exempting from rate limiting for probe reliability.

---

## GET `/api/v1/health/ready`

Kubernetes **readiness** probe. Indicates whether the service is ready to accept traffic, including dependency checks.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/health/ready
```

### Response `200 OK`

```json
{
  "ready": true,
  "checks": {
    "database": true,
    "service": true
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `ready` | boolean | Overall readiness status |
| `checks.database` | boolean | Database connectivity check |
| `checks.service` | boolean | Core service check |

### Audit Status

- **Pass** — Recommend exempting from rate limiting for probe reliability.

---

## GET `/api/v1/health/startup`

Kubernetes **startup** probe. Indicates whether the service has completed its initialization sequence.

### Example Request

```bash
curl -X GET https://api.blocksecops.example.com/api/v1/health/startup
```

### Response `200 OK`

```json
{
  "started": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `started` | boolean | Whether the service has fully started |

### Audit Status

- **Pass** — Recommend exempting from rate limiting for probe reliability.
