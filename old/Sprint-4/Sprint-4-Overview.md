# Sprint 4: Security Tool Integration & Orchestration

**Duration**: Weeks 7-8 (2 weeks)
**Status**: Planning
**Technical Milestone**: Core security tool integration with workflow orchestration

---

## Overview

Sprint 4 establishes the foundation of the security analysis platform by integrating core security tools (Slither, Aderyn, Mythril) and building the orchestration infrastructure for parallel tool execution. This sprint also introduces URL-based contract scanning for multi-chain support and implements a basic intelligence engine for result processing.

### Key Objectives

1. **Tool Integration**: Implement adapters for Slither, Aderyn, and Mythril
2. **Orchestration System**: Build Celery-based job queue with parallel execution
3. **Contract Parser**: Develop high-performance Rust-based Solidity parser
4. **Intelligence Engine**: Create basic deduplication and risk scoring system
5. **URL Scanning**: Enable contract fetching from blockchain explorers
6. **Platform Integration**: Deploy all services to staging via ArgoCD

---

## Technical Milestone

**Deliverable**: Functional security analysis platform with multi-tool support and intelligent result aggregation

**Success Criteria**:
- 3 security tools (Slither, Aderyn, Mythril) integrated
- Parallel tool execution working reliably
- Contract parser providing accurate AST analysis
- Basic intelligence engine operational
- URL-based scanning functional for multiple chains
- All services deployed to staging environment
- All acceptance criteria met

---

## Epic 1: Tool Integration Service Development

### Epic Goal
Implement adapters for core security analysis tools with standardized result normalization.

### Tasks

#### Task 4.1: Tool Integration Service Foundation

**Story**: As the orchestration service, I need a tool integration framework so that I can execute security tools consistently.

**Acceptance Criteria**:
- [ ] Tool integration service repository initialized
- [ ] Base `ToolAdapter` abstract class implemented
- [ ] Tool registry and factory pattern created
- [ ] Result normalization schema defined
- [ ] Error handling framework established
- [ ] Unit tests for base infrastructure

**Implementation**:
```python
# src/domain/interfaces/tool_adapter.py
class ToolAdapter(ABC):
    @abstractmethod
    async def analyze(self, contract: Contract) -> AnalysisResult:
        pass

    @abstractmethod
    def normalize_results(self, raw_results: Dict) -> List[Finding]:
        pass

    @abstractmethod
    def get_tool_info(self) -> ToolInfo:
        pass
```

**Estimated Time**: 8 hours

**Dependencies**: Sprint 3 backend services

---

#### Task 4.2: Slither Adapter Implementation

**Story**: As a security analyst, I want Slither analysis integrated so that I can detect common Solidity vulnerabilities.

**Acceptance Criteria**:
- [ ] Slither Python package integration working
- [ ] Slither analysis execution via subprocess
- [ ] JSON output parsing implemented
- [ ] Result normalization to standard schema
- [ ] 50+ Slither detectors mapped
- [ ] Error handling for compilation failures
- [ ] Slither version management
- [ ] Unit and integration tests passing

**Implementation Details**:
```python
# src/infrastructure/tools/slither_adapter.py
class SlitherAdapter(ToolAdapter):
    def __init__(self, solc_version_manager: SolcVersionManager):
        self.tool_name = "slither"
        self.version = "0.10.0"

    async def analyze(self, contract: Contract) -> AnalysisResult:
        # Configure solc version
        # Write contract to temp file
        # Execute slither with JSON output
        # Parse and normalize results
```

**Slither Detector Coverage**:
- High severity: reentrancy, unprotected selfdestruct, suicidal
- Medium severity: arbitrary-send-eth, controlled-delegatecall
- Low severity: naming-convention, solc-version, pragma
- Optimization: constable-states, external-function

**Estimated Time**: 12 hours

**Dependencies**: Task 4.1

---

#### Task 4.3: Aderyn Adapter Implementation

**Story**: As a security analyst, I want Aderyn analysis integrated so that I can detect modern Solidity patterns and vulnerabilities.

**Acceptance Criteria**:
- [ ] Aderyn Rust CLI integration working
- [ ] CLI wrapper with proper error handling
- [ ] JSON output parsing implemented
- [ ] Result normalization to standard schema
- [ ] Aderyn-specific detector mapping
- [ ] Support for Solidity 0.8+ features
- [ ] Integration tests with sample contracts

**Implementation Details**:
```python
# src/infrastructure/tools/aderyn_adapter.py
class AderynAdapter(ToolAdapter):
    def __init__(self, aderyn_path: str = "/usr/local/bin/aderyn"):
        self.tool_name = "aderyn"
        self.cli_path = aderyn_path

    async def analyze(self, contract: Contract) -> AnalysisResult:
        # Execute aderyn CLI with contract directory
        # Parse JSON output format
        # Normalize to standard findings
```

**Aderyn Detector Focus**:
- Foundry-specific patterns
- Modern Solidity 0.8+ issues
- Gas optimization patterns
- Best practices violations

**Estimated Time**: 10 hours

**Dependencies**: Task 4.1

---

#### Task 4.4: Tool Rate Limiting & Quota Management

**Story**: As a platform operator, I need rate limiting for security tools so that we don't exceed API quotas and manage resources efficiently.

**Acceptance Criteria**:
- [ ] Rate limiter implementation using token bucket algorithm
- [ ] Per-tool quota configuration
- [ ] Redis-backed rate limit tracking
- [ ] Quota exceeded error handling
- [ ] Rate limit metrics exposed
- [ ] Configuration via environment variables
- [ ] Unit tests for rate limiting logic

**Implementation**:
```python
# src/infrastructure/rate_limiting/tool_rate_limiter.py
class ToolRateLimiter:
    def __init__(self, redis_client: Redis):
        self.limits = {
            "slither": {"rate": 100, "period": 60},  # 100 per minute
            "aderyn": {"rate": 50, "period": 60},
            "mythril": {"rate": 10, "period": 60}     # API limited
        }

    async def acquire(self, tool_name: str) -> bool:
        # Token bucket algorithm implementation
        pass
```

**Estimated Time**: 6 hours

**Dependencies**: Task 4.2, Task 4.3

---

#### Task 4.5: Tool Integration Service Deployment

**Story**: As a DevOps engineer, I need to deploy the tool integration service so that it's available in staging.

**Acceptance Criteria**:
- [ ] Dockerfile created with all tool dependencies
- [ ] Kubernetes manifests created
- [ ] Kustomize overlays for staging
- [ ] HashiCorp Vault integration for tool credentials
- [ ] Service deployed via ArgoCD
- [ ] Health check endpoint operational
- [ ] Monitoring and logging configured
- [ ] Integration tests passing in staging

**Docker Configuration**:
```dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    build-essential

# Install Aderyn (Rust binary)
RUN curl -L https://github.com/Cyfrin/aderyn/releases/download/latest/aderyn -o /usr/local/bin/aderyn
RUN chmod +x /usr/local/bin/aderyn

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . /app
WORKDIR /app
```

**Estimated Time**: 8 hours

**Dependencies**: Task 4.2, Task 4.3, Task 4.4

---

## Epic 2: Orchestration Service Development

### Epic Goal
Build robust job queue system for managing parallel tool execution with retry logic.

### Tasks

#### Task 4.6: Celery-Based Orchestration Infrastructure

**Story**: As a platform architect, I need a job queue system so that I can manage asynchronous analysis tasks at scale.

**Acceptance Criteria**:
- [ ] Celery configured with Redis broker
- [ ] Task queues defined (high, normal, low priority)
- [ ] Worker configuration optimized
- [ ] Result backend configured
- [ ] Celery beat for scheduled tasks
- [ ] Monitoring with Flower dashboard
- [ ] Integration tests for task execution

**Implementation**:
```python
# src/infrastructure/orchestration/celery_app.py
from celery import Celery

celery_app = Celery(
    "orchestration",
    broker="redis://redis:6379/0",
    backend="redis://redis:6379/1"
)

celery_app.conf.task_routes = {
    "orchestration.tasks.high_priority": {"queue": "high"},
    "orchestration.tasks.normal": {"queue": "normal"},
    "orchestration.tasks.low_priority": {"queue": "low"}
}
```

**Estimated Time**: 10 hours

**Dependencies**: Sprint 3 Redis deployment

---

#### Task 4.7: Parallel Tool Execution Engine

**Story**: As an orchestration service, I need to execute multiple tools in parallel so that analysis completes faster.

**Acceptance Criteria**:
- [ ] Parallel execution task implemented
- [ ] Tool dependency resolution
- [ ] Resource management (CPU, memory limits)
- [ ] Partial failure handling
- [ ] Result aggregation from all tools
- [ ] Execution time tracking
- [ ] Unit and integration tests

**Implementation**:
```python
# src/application/services/analysis_orchestrator.py
class AnalysisOrchestrator:
    async def execute_analysis(self, contract_id: str, tools: List[str]) -> str:
        """Execute tools in parallel and aggregate results"""
        tasks = [
            self.execute_tool.delay(contract_id, tool)
            for tool in tools
        ]

        results = await asyncio.gather(*tasks, return_exceptions=True)
        return await self.aggregate_results(contract_id, results)
```

**Estimated Time**: 12 hours

**Dependencies**: Task 4.6, Task 4.5

---

#### Task 4.8: Retry Logic with Exponential Backoff

**Story**: As a platform operator, I need automatic retry for failed analyses so that transient failures don't require manual intervention.

**Acceptance Criteria**:
- [ ] Retry decorator implemented
- [ ] Exponential backoff calculation
- [ ] Max retry limit configuration
- [ ] Retry metrics tracked
- [ ] Dead letter queue for permanent failures
- [ ] Notification on permanent failure
- [ ] Tests for retry scenarios

**Implementation**:
```python
@celery_app.task(
    bind=True,
    autoretry_for=(ToolExecutionException,),
    retry_backoff=True,
    retry_backoff_max=600,  # 10 minutes
    retry_jitter=True,
    max_retries=3
)
def execute_tool_with_retry(self, contract_id: str, tool_name: str):
    # Execute tool analysis
    pass
```

**Estimated Time**: 6 hours

**Dependencies**: Task 4.7

---

#### Task 4.9: Analysis Status Tracking

**Story**: As a user, I need real-time status updates on my analysis so that I know what's happening.

**Acceptance Criteria**:
- [ ] Status tracking database schema
- [ ] Status update API endpoints
- [ ] Real-time status via WebSocket
- [ ] Status history tracking
- [ ] Progress percentage calculation
- [ ] Estimated completion time
- [ ] Integration with notification service

**Database Schema**:
```sql
CREATE TABLE analysis_status (
    id UUID PRIMARY KEY,
    analysis_id UUID REFERENCES analyses(id),
    tool_name VARCHAR(50),
    status VARCHAR(20), -- queued, running, completed, failed
    progress_percentage INTEGER,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    error_message TEXT,
    updated_at TIMESTAMP
);
```

**Status Flow**:
1. `queued` - Analysis added to queue
2. `running` - Tool execution started
3. `completed` - Tool finished successfully
4. `failed` - Tool execution failed (after retries)

**Estimated Time**: 8 hours

**Dependencies**: Task 4.7, Sprint 3 notification service

---

#### Task 4.10: Orchestration Service Deployment

**Story**: As a DevOps engineer, I need to deploy the orchestration service with Celery workers so that job processing works in staging.

**Acceptance Criteria**:
- [ ] Orchestration service Docker image built
- [ ] Kubernetes Deployment for API service
- [ ] Kubernetes Deployment for Celery workers
- [ ] Horizontal Pod Autoscaler configured
- [ ] Vault integration for secrets
- [ ] Deployed via ArgoCD
- [ ] Health checks operational
- [ ] Monitoring dashboards created

**Kubernetes Resources**:
```yaml
# k8s/orchestration/deployment-workers.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orchestration-workers
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: celery-worker
        image: orchestration-service:latest
        command: ["celery", "-A", "app.celery_app", "worker", "-Q", "normal,high,low"]
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
```

**Estimated Time**: 10 hours

**Dependencies**: Task 4.8, Task 4.9

---

## Epic 3: Contract Parser Service

### Epic Goal
Develop high-performance Rust-based Solidity parser for AST generation and dependency analysis.

### Tasks

#### Task 4.11: Rust Parser Service Foundation

**Story**: As a developer, I need a fast Solidity parser so that I can extract contract structure and dependencies efficiently.

**Acceptance Criteria**:
- [ ] Rust project initialized
- [ ] Solidity parser library integrated (solang or tree-sitter)
- [ ] HTTP API framework setup (Actix-web or Axum)
- [ ] Basic parse endpoint implemented
- [ ] Error handling for invalid Solidity
- [ ] Unit tests for parser core

**Implementation**:
```rust
// src/main.rs
use actix_web::{web, App, HttpServer};
use solang_parser::parse;

#[post("/parse")]
async fn parse_contract(body: web::Json<ParseRequest>) -> Result<HttpResponse> {
    let (ast, errors) = parse(&body.source_code, 0);

    if !errors.is_empty() {
        return Err(ParseError::from(errors));
    }

    Ok(HttpResponse::Ok().json(ParserResponse {
        ast: serialize_ast(ast),
        source_map: generate_source_map(&ast),
    }))
}
```

**Estimated Time**: 12 hours

**Dependencies**: None

---

#### Task 4.12: AST Generation & Source Mapping

**Story**: As a tool integration service, I need AST with source mapping so that I can map findings to specific code locations.

**Acceptance Criteria**:
- [ ] Complete AST generation implemented
- [ ] Source location mapping for all nodes
- [ ] Line/column number extraction
- [ ] Function and variable extraction
- [ ] Contract inheritance analysis
- [ ] JSON serialization of AST
- [ ] Tests with complex contracts

**AST Output Format**:
```json
{
  "contracts": [
    {
      "name": "MyContract",
      "type": "contract",
      "location": {"start": 0, "end": 245, "line": 1, "column": 1},
      "functions": [
        {
          "name": "transfer",
          "visibility": "public",
          "location": {"start": 50, "end": 120, "line": 5, "column": 3}
        }
      ]
    }
  ]
}
```

**Estimated Time**: 10 hours

**Dependencies**: Task 4.11

---

#### Task 4.13: Dependency Analysis & Import Resolution

**Story**: As a contract analyzer, I need dependency graph so that I can understand contract relationships.

**Acceptance Criteria**:
- [ ] Import statement extraction
- [ ] Dependency graph generation
- [ ] External contract identification
- [ ] Library usage detection
- [ ] Circular dependency detection
- [ ] Dependency resolution order
- [ ] Tests with multi-file contracts

**Implementation**:
```rust
pub struct DependencyAnalyzer {
    imports: Vec<ImportStatement>,
}

impl DependencyAnalyzer {
    pub fn analyze(&self, ast: &SourceUnit) -> DependencyGraph {
        // Extract all import statements
        // Build dependency graph
        // Detect circular dependencies
        // Return topological order
    }
}
```

**Estimated Time**: 8 hours

**Dependencies**: Task 4.12

---

#### Task 4.14: Parser Caching Strategy

**Story**: As a platform operator, I need parser result caching so that repeated parsing is fast and efficient.

**Acceptance Criteria**:
- [ ] Redis caching layer implemented
- [ ] Cache key generation (contract hash)
- [ ] TTL configuration for cache entries
- [ ] Cache invalidation logic
- [ ] Cache hit/miss metrics
- [ ] Tests for cache behavior

**Implementation**:
```rust
pub struct ParserCache {
    redis_client: redis::Client,
    ttl_seconds: u64,
}

impl ParserCache {
    pub async fn get_or_parse(&self, source_code: &str) -> Result<ParseResult> {
        let cache_key = Self::generate_cache_key(source_code);

        if let Some(cached) = self.get_cached(&cache_key).await? {
            return Ok(cached);
        }

        let result = self.parse(source_code)?;
        self.cache(&cache_key, &result).await?;
        Ok(result)
    }
}
```

**Estimated Time**: 6 hours

**Dependencies**: Task 4.13, Sprint 3 Redis deployment

---

#### Task 4.15: Contract Parser Service Deployment

**Story**: As a DevOps engineer, I need to deploy the parser service so that it's available for contract analysis.

**Acceptance Criteria**:
- [ ] Rust Docker image optimized (multi-stage build)
- [ ] Kubernetes manifests created
- [ ] Horizontal pod autoscaler configured
- [ ] Service endpoints documented
- [ ] Deployed via ArgoCD
- [ ] Health check endpoint working
- [ ] Performance metrics exposed
- [ ] Load testing completed

**Docker Multi-Stage Build**:
```dockerfile
# Build stage
FROM rust:1.75 as builder
WORKDIR /usr/src/app
COPY . .
RUN cargo build --release

# Runtime stage
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates
COPY --from=builder /usr/src/app/target/release/parser-service /usr/local/bin/
EXPOSE 8080
CMD ["parser-service"]
```

**Estimated Time**: 8 hours

**Dependencies**: Task 4.14

---

## Epic 4: Basic Intelligence Engine

### Epic Goal
Create intelligence layer for result deduplication and risk scoring.

### Tasks

#### Task 4.16: Deduplication Algorithms

**Story**: As an intelligence engine, I need to deduplicate findings from multiple tools so that users don't see the same issue multiple times.

**Acceptance Criteria**:
- [ ] Exact match deduplication implemented
- [ ] Syntactic similarity using Levenshtein distance
- [ ] Location-based deduplication (file/line matching)
- [ ] Hash-based deduplication for messages
- [ ] Configurable similarity thresholds
- [ ] Deduplication metrics tracked
- [ ] Unit tests with various finding sets

**Implementation**:
```python
# src/domain/services/deduplication_service.py
class DeduplicationService:
    def deduplicate(self, findings: List[Finding]) -> List[Finding]:
        deduplicated = []
        seen_hashes = set()

        for finding in findings:
            # Exact match check
            exact_hash = self.compute_exact_hash(finding)
            if exact_hash in seen_hashes:
                continue

            # Fuzzy match check
            if not self.is_similar_to_existing(finding, deduplicated):
                deduplicated.append(finding)
                seen_hashes.add(exact_hash)

        return deduplicated
```

**Deduplication Strategy**:
1. Exact hash matching (message + location)
2. Location overlap (same file, overlapping lines)
3. Semantic similarity (Levenshtein distance > 0.8)
4. Tool consensus (same vulnerability type)

**Estimated Time**: 10 hours

**Dependencies**: Task 4.5 (tool integration results)

---

#### Task 4.17: Rule-Based Risk Scoring

**Story**: As a security analyst, I need risk scores for findings so that I can prioritize remediation efforts.

**Acceptance Criteria**:
- [ ] Severity-based scoring implemented
- [ ] Confidence multipliers applied
- [ ] Cross-tool validation scoring
- [ ] Context-based adjustments
- [ ] Scoring rules configurable
- [ ] Score explanation generated
- [ ] Tests with various finding types

**Scoring Formula**:
```python
base_score = severity_weight * confidence_multiplier
cross_tool_bonus = 0.2 * number_of_tools_reporting
context_adjustment = context_rules.evaluate(finding)

final_score = (base_score + cross_tool_bonus) * context_adjustment
```

**Severity Weights**:
- Critical: 10.0
- High: 7.5
- Medium: 5.0
- Low: 2.5
- Informational: 1.0

**Confidence Multipliers**:
- High: 1.0
- Medium: 0.7
- Low: 0.4

**Estimated Time**: 8 hours

**Dependencies**: Task 4.16

---

#### Task 4.18: Intelligence Engine Service

**Story**: As a platform, I need an intelligence engine service so that analysis results are processed and enriched.

**Acceptance Criteria**:
- [ ] Intelligence engine API implemented
- [ ] Deduplication endpoint working
- [ ] Risk scoring endpoint working
- [ ] Bulk processing support
- [ ] Performance optimization (async processing)
- [ ] Integration with orchestration service
- [ ] Unit and integration tests

**API Endpoints**:
```
POST /api/v1/intelligence/deduplicate
POST /api/v1/intelligence/score
POST /api/v1/intelligence/process    # Combined dedup + score
```

**Estimated Time**: 8 hours

**Dependencies**: Task 4.16, Task 4.17

---

#### Task 4.19: Intelligence Engine Deployment

**Story**: As a DevOps engineer, I need to deploy the intelligence engine so that it's integrated with the analysis pipeline.

**Acceptance Criteria**:
- [ ] Docker image created
- [ ] Kubernetes manifests created
- [ ] Deployed via ArgoCD
- [ ] Service endpoints accessible
- [ ] Health checks operational
- [ ] Monitoring configured
- [ ] Performance metrics exposed

**Estimated Time**: 6 hours

**Dependencies**: Task 4.18

---

## Epic 5: URL-Based Contract Scanning

### Epic Goal
Enable contract analysis directly from blockchain explorer URLs.

### Tasks

#### Task 4.20: Blockchain Explorer API Integration

**Story**: As a user, I want to analyze contracts by providing a blockchain explorer URL so that I don't need to manually copy source code.

**Acceptance Criteria**:
- [ ] Etherscan API integration implemented
- [ ] Blockscout API integration implemented
- [ ] API key management via Vault
- [ ] Rate limiting for explorer APIs
- [ ] Response parsing and validation
- [ ] Error handling for API failures
- [ ] Unit tests with mocked APIs

**Implementation**:
```python
# src/infrastructure/blockchain/explorer_client.py
class EtherscanClient:
    def __init__(self, api_key: str, network: str):
        self.api_key = api_key
        self.base_url = self.get_base_url(network)

    async def get_contract_source(self, address: str) -> ContractSource:
        url = f"{self.base_url}/api?module=contract&action=getsourcecode&address={address}"
        response = await self.http_client.get(url)
        return self.parse_response(response)
```

**Supported Networks**:
- Ethereum Mainnet (etherscan.io)
- BSC (bscscan.com)
- Polygon (polygonscan.com)
- Arbitrum (arbiscan.io)
- Optimism (optimistic.etherscan.io)

**Estimated Time**: 10 hours

**Dependencies**: Sprint 3 API service

---

#### Task 4.21: Multi-Chain Support

**Story**: As a user, I want to analyze contracts from multiple blockchain networks so that I can audit projects on any chain.

**Acceptance Criteria**:
- [ ] Network selection endpoint implemented
- [ ] Network-specific API configuration
- [ ] Network validation logic
- [ ] Chain ID verification
- [ ] Network selector in frontend
- [ ] Tests for all supported networks

**Network Configuration**:
```python
NETWORK_CONFIG = {
    "ethereum": {
        "chain_id": 1,
        "explorer": "etherscan",
        "api_url": "https://api.etherscan.io/api"
    },
    "bsc": {
        "chain_id": 56,
        "explorer": "bscscan",
        "api_url": "https://api.bscscan.com/api"
    },
    # ... other networks
}
```

**Estimated Time**: 6 hours

**Dependencies**: Task 4.20

---

#### Task 4.22: Contract Source Verification

**Story**: As a security platform, I need to verify contract source matches blockchain bytecode so that users can trust the analysis.

**Acceptance Criteria**:
- [ ] Bytecode fetching from blockchain
- [ ] Source compilation with correct solc version
- [ ] Bytecode comparison logic
- [ ] Verification status in analysis results
- [ ] Warning for unverified contracts
- [ ] Tests with verified and unverified contracts

**Implementation**:
```python
# src/application/services/contract_verification.py
class ContractVerifier:
    async def verify_source(
        self,
        address: str,
        source_code: str,
        compiler_version: str
    ) -> VerificationResult:
        # Fetch deployed bytecode from blockchain
        deployed = await self.web3_client.get_code(address)

        # Compile source code
        compiled = await self.compiler.compile(source_code, compiler_version)

        # Compare bytecodes
        return self.compare_bytecode(deployed, compiled)
```

**Estimated Time**: 8 hours

**Dependencies**: Task 4.21

---

#### Task 4.23: URL Scanning Endpoint

**Story**: As a user, I want a simple endpoint to analyze contracts by URL so that my workflow is streamlined.

**Acceptance Criteria**:
- [ ] `POST /api/v1/contracts/from-url` endpoint created
- [ ] URL validation and parsing
- [ ] Network detection from URL
- [ ] Contract address extraction
- [ ] Automatic analysis trigger
- [ ] Response with analysis ID
- [ ] Integration tests

**Request Format**:
```json
{
  "url": "https://etherscan.io/address/0x123...",
  "network": "ethereum",  // optional, auto-detected
  "analysis_options": {
    "tools": ["slither", "aderyn", "mythril"],
    "priority": "normal"
  }
}
```

**Response Format**:
```json
{
  "analysis_id": "uuid",
  "contract_address": "0x123...",
  "network": "ethereum",
  "status": "queued",
  "verification_status": "verified"
}
```

**Estimated Time**: 6 hours

**Dependencies**: Task 4.22

---

#### Task 4.24: URL Scanning Integration Testing

**Story**: As QA, I need comprehensive tests for URL scanning so that it works reliably across all supported networks.

**Acceptance Criteria**:
- [ ] End-to-end tests for each network
- [ ] Error scenario tests (invalid address, network down)
- [ ] Rate limiting tests
- [ ] Verification failure tests
- [ ] Performance tests
- [ ] Documentation updated

**Estimated Time**: 6 hours

**Dependencies**: Task 4.23

---

## Sprint Backlog

### Week 1: Tool Integration & Orchestration Foundation

**Day 1-2**: Tool Integration Setup
- Task 4.1: Tool integration foundation (8h)
- Task 4.2: Slither adapter (12h)

**Day 3**: Additional Tools
- Task 4.3: Aderyn adapter (10h)
- Task 4.4: Rate limiting (6h, started)

**Day 4**: Orchestration Infrastructure
- Task 4.4: Rate limiting (completed)
- Task 4.6: Celery orchestration (10h)

**Day 5**: Orchestration Features
- Task 4.7: Parallel execution (12h)
- Task 4.8: Retry logic (6h, started)

### Week 2: Parser, Intelligence & URL Scanning

**Day 6**: Parser Service
- Task 4.8: Retry logic (completed)
- Task 4.11: Rust parser foundation (12h)
- Task 4.12: AST generation (10h, started)

**Day 7**: Parser Completion
- Task 4.12: AST generation (completed)
- Task 4.13: Dependency analysis (8h)
- Task 4.14: Parser caching (6h)

**Day 8**: Intelligence Engine
- Task 4.16: Deduplication (10h)
- Task 4.17: Risk scoring (8h)
- Task 4.18: Intelligence service (8h, started)

**Day 9**: URL Scanning
- Task 4.18: Intelligence service (completed)
- Task 4.20: Explorer API integration (10h)
- Task 4.21: Multi-chain support (6h)

**Day 10**: Deployment & Integration
- Task 4.9: Status tracking (8h)
- Task 4.22: Source verification (8h)
- Task 4.23: URL scanning endpoint (6h)
- Task 4.5: Tool service deployment (8h, parallel)
- Task 4.10: Orchestration deployment (10h, parallel)
- Task 4.15: Parser deployment (8h, parallel)
- Task 4.19: Intelligence deployment (6h, parallel)
- Task 4.24: Integration testing (6h)

---

## Acceptance Criteria

### Tool Integration
- [ ] Slither adapter analyzing contracts successfully
- [ ] Aderyn adapter analyzing contracts successfully
- [ ] Tool results normalized to standard schema
- [ ] Rate limiting preventing quota exhaustion
- [ ] 50+ vulnerability types detected across tools

### Orchestration
- [ ] Job queue processing analyses with priority
- [ ] Parallel execution of 3 tools completing in <5 minutes
- [ ] Failed analyses retry automatically (3 attempts)
- [ ] Dead letter queue capturing permanent failures
- [ ] Real-time status updates via WebSocket

### Contract Parser
- [ ] Rust parser generating accurate AST
- [ ] Source mapping providing line/column info
- [ ] Dependency analysis extracting import graph
- [ ] Parser caching reducing repeated work by 80%
- [ ] Parser handling invalid Solidity gracefully

### Intelligence Engine
- [ ] Basic deduplication reducing duplicate findings by 40-60%
- [ ] Risk scoring providing consistent assessments
- [ ] Cross-tool validation increasing confidence scores
- [ ] Intelligence processing completing in <2 seconds

### URL-Based Scanning
- [ ] URL scanning working for Etherscan
- [ ] URL scanning working for Blockscout
- [ ] Multi-chain support for 5 networks (Ethereum, BSC, Polygon, Arbitrum, Optimism)
- [ ] Source verification against bytecode successful
- [ ] Contract address validation preventing invalid inputs

### Deployment
- [ ] All services deployed to staging via ArgoCD
- [ ] Health checks operational for all services
- [ ] Monitoring dashboards showing service metrics
- [ ] Integration tests passing in staging
- [ ] Services accessible via AWS ALB with authentication

---

## Risks & Mitigation

### Risk 1: Tool Execution Reliability
**Impact**: Critical
**Probability**: Medium
**Mitigation**:
- Comprehensive error handling in adapters
- Retry logic with exponential backoff
- Tool failure isolation (one tool failure doesn't block others)
- Extensive testing with problematic contracts
- Fallback to alternative tools

### Risk 2: Performance Bottlenecks
**Impact**: High
**Probability**: Medium
**Mitigation**:
- Parallel tool execution reduces total time
- Parser result caching eliminates redundant work
- Redis for fast status tracking
- Horizontal pod autoscaling for workers
- Load testing before production

### Risk 3: API Rate Limits (Blockchain Explorers)
**Impact**: Medium
**Probability**: High
**Mitigation**:
- Implement aggressive rate limiting
- Multiple API keys with rotation
- Caching of contract source code
- Queue requests during high usage
- User notifications about delays

### Risk 4: Parser Accuracy
**Impact**: High
**Probability**: Low
**Mitigation**:
- Use battle-tested parsing library (solang)
- Extensive testing with diverse contracts
- Graceful degradation for parsing failures
- Manual validation of AST output
- Community feedback loop

### Risk 5: Tool Version Compatibility
**Impact**: Medium
**Probability**: Medium
**Mitigation**:
- Version pinning in Docker images
- Version compatibility matrix documented
- Automated testing on version updates
- Solc version management for Slither
- Tool update process documented

---

## Success Metrics

### Performance Metrics
- Analysis completion time: <5 minutes for 3 tools
- Parser response time: <500ms per contract
- Intelligence processing: <2 seconds per analysis
- Job queue throughput: >100 analyses/hour
- Service availability: >99.5% uptime

### Quality Metrics
- Deduplication accuracy: >80% duplicate reduction
- Risk scoring consistency: <10% variance
- Tool execution success rate: >95%
- Parser accuracy: 100% for valid Solidity
- Source verification success: >90%

### Operational Metrics
- Rate limit violations: <5 per day
- Failed job retry success rate: >70%
- Cache hit ratio: >60% for parser
- Dead letter queue size: <1% of total jobs
- Alert response time: <5 minutes

---

## Documentation

### Implementation Guides
- Tool Integration Architecture: `/Users/pwner/Git/ABS/TaskDocs/SolidityOps/tool-integration-architecture.md`
- Orchestration System Design: `/Users/pwner/Git/ABS/TaskDocs/SolidityOps/orchestration-design.md`
- Parser Service Documentation: (to be created)
- Intelligence Engine Guide: (to be created)

### API Documentation
- Tool Integration API Reference
- Orchestration API Reference
- Contract Parser API Reference
- Intelligence Engine API Reference
- URL Scanning API Guide

### Operational Documentation
- Tool Deployment Guide
- Monitoring and Alerting Setup
- Troubleshooting Common Issues
- Rate Limit Configuration
- Celery Worker Management

---

## Dependencies

### External Dependencies
- Slither Python package (pip installable)
- Aderyn Rust binary (pre-built or compiled)
- Solidity compiler (solc) multiple versions
- Redis for Celery broker and caching
- PostgreSQL for status tracking

### Internal Dependencies
- Sprint 3: Core backend services (API, Data, Notification)
- Sprint 3: PostgreSQL and Redis deployed in Kubernetes
- Sprint 3: HashiCorp Vault for secrets management
- Sprint 2: ArgoCD for GitOps deployments
- Sprint 2: Istio service mesh for networking

### Infrastructure Dependencies
- Kubernetes cluster with sufficient resources
- Docker registry (ECR) for images
- AWS ALB for service ingress
- Prometheus/Grafana for monitoring
- HashiCorp Vault operational

---

## Post-Sprint Activities

### Sprint Review
- Demo URL-based contract scanning
- Demo parallel tool execution
- Show real-time status tracking
- Present deduplication effectiveness
- Review architecture decisions

### Sprint Retrospective
- Tool integration challenges
- Orchestration performance tuning
- Parser development learnings
- Deployment automation improvements
- Team collaboration effectiveness

### Backlog Grooming for Sprint 5
- Frontend requirements refinement
- Real-time WebSocket specification
- Dashboard mockup review
- Component library planning
- Integration testing strategy

---

**Sprint 4 Team**: Backend Engineers (4), Rust Developer (1), DevOps Engineer (1), QA Engineer (1)
**Sprint Goal**: Deliver functional security analysis platform with multi-tool orchestration
**Definition of Done**: All acceptance criteria met, services deployed to staging, integration tests passing, documentation complete
