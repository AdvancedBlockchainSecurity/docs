# Semantic Fingerprinting Roadmap

**Objective**: Evolution from rule-based to ML-powered semantic fingerprinting
**Timeline**: 2025-2026
**Status**: Roadmap Defined
**Created**: 2025-11-01

---

## Current State (Q4 2025)

### Phase 0: Rule-Based Fingerprinting ✅ COMPLETE

**Implemented**:
- ✅ Code hashing with normalization (CodeHasher)
- ✅ Location hashing with fuzzy matching (LocationHasher)
- ✅ AST-based structural hashing (ASTHasher)
- ✅ Pattern matching via detector mappings (397 mappings)
- ✅ Cross-scanner deduplication (0% collision rate)

**Metrics**:
- Pattern matching accuracy: 100% (397/397)
- Deduplication accuracy: >95%
- Collision rate: <1%
- Processing speed: ~0.15ms per finding

**Limitations**:
- Requires exact or near-exact code matches
- Limited to known patterns
- Cannot detect semantically similar but syntactically different code
- No understanding of code intent or behavior

---

## Phase 1: Semantic Embeddings (Q1-Q2 2026)

### Objective

Enable semantic similarity matching using code embeddings that understand code meaning beyond syntax.

### Technology Stack

**Model Selection**:
- **Primary**: CodeBERT (Microsoft) - pre-trained on code
- **Alternative**: GraphCodeBERT - includes dataflow
- **Evaluation**: UniXcoder, StarCoder embeddings

**Infrastructure**:
- Vector database: Qdrant or Weaviate
- Embedding dimension: 768 (CodeBERT)
- Similarity metric: Cosine similarity

### Implementation

```python
from transformers import AutoTokenizer, AutoModel
import torch

class SemanticFingerprintGenerator:
    """Generate semantic embeddings for code snippets."""

    def __init__(self):
        self.tokenizer = AutoTokenizer.from_pretrained("microsoft/codebert-base")
        self.model = AutoModel.from_pretrained("microsoft/codebert-base")

    def generate_embedding(self, code: str) -> np.ndarray:
        """
        Generate 768-dimensional semantic embedding.

        Args:
            code: Source code snippet

        Returns:
            768-dimensional vector
        """
        # Tokenize
        inputs = self.tokenizer(
            code,
            return_tensors="pt",
            max_length=512,
            truncation=True,
            padding=True
        )

        # Generate embedding
        with torch.no_grad():
            outputs = self.model(**inputs)

        # Use [CLS] token embedding
        embedding = outputs.last_hidden_state[:, 0, :].numpy()

        return embedding.flatten()

    def calculate_similarity(self, embedding1: np.ndarray, embedding2: np.ndarray) -> float:
        """
        Calculate cosine similarity between embeddings.

        Returns:
            Similarity score 0.0-1.0
        """
        return cosine_similarity([embedding1], [embedding2])[0][0]
```

### Use Cases

**1. Semantic Code Matching**:

```python
code1 = """
function withdraw() public {
    uint amount = balances[msg.sender];
    msg.sender.call{value: amount}("");
    balances[msg.sender] = 0;
}
"""

code2 = """
function cashOut() external {
    uint256 userBalance = balance[msg.sender];
    payable(msg.sender).call{value: userBalance}("");
    balance[msg.sender] = 0;
}
"""

# Both are reentrancy vulnerabilities despite different code
embedding1 = generator.generate_embedding(code1)
embedding2 = generator.generate_embedding(code2)

similarity = generator.calculate_similarity(embedding1, embedding2)
# Expected: > 0.85 (semantically similar)
```

**2. Fuzzy Deduplication**:

```python
def find_similar_vulnerabilities(
    new_finding: ParsedFinding,
    existing_findings: list,
    threshold: float = 0.80
) -> list:
    """
    Find semantically similar vulnerabilities.

    Args:
        new_finding: New vulnerability to match
        existing_findings: Database of existing vulnerabilities
        threshold: Similarity threshold (0.0-1.0)

    Returns:
        List of similar findings with similarity scores
    """
    new_embedding = generate_embedding(new_finding.code_snippet)

    similar = []
    for existing in existing_findings:
        existing_embedding = existing.semantic_embedding

        similarity = calculate_similarity(new_embedding, existing_embedding)

        if similarity >= threshold:
            similar.append({
                "finding": existing,
                "similarity": similarity,
                "confidence": "high" if similarity > 0.90 else "medium"
            })

    return sorted(similar, key=lambda x: x["similarity"], reverse=True)
```

### Database Schema Updates

```sql
-- Add semantic embedding column
ALTER TABLE vulnerabilities
ADD COLUMN semantic_embedding vector(768);  -- pgvector extension

-- Create vector index for similarity search
CREATE INDEX idx_vulnerabilities_semantic_embedding
ON vulnerabilities
USING ivfflat (semantic_embedding vector_cosine_ops)
WITH (lists = 100);

-- Example similarity query
SELECT id, title, 1 - (semantic_embedding <=> query_embedding) AS similarity
FROM vulnerabilities
WHERE 1 - (semantic_embedding <=> query_embedding) > 0.80
ORDER BY semantic_embedding <=> query_embedding
LIMIT 10;
```

### Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Embedding generation | <100ms | Per code snippet |
| Similarity search | <50ms | Against 100k vectors |
| Semantic match accuracy | >85% | vs rule-based 100% |
| Storage per finding | +3KB | 768 floats × 4 bytes |

### Deliverables

- [ ] CodeBERT integration
- [ ] Vector database setup (Qdrant/Weaviate)
- [ ] Semantic embedding generation pipeline
- [ ] Similarity search API
- [ ] Hybrid matching (rule-based + semantic)

---

## Phase 2: ML-Based Deduplication (Q3 2026)

### Objective

Train ML models to learn optimal deduplication strategies and improve accuracy over time.

### Approach

**Supervised Learning**:
- Training data: Historical deduplications (manual + rule-based)
- Features: Code embeddings + metadata (scanner, severity, location)
- Model: Binary classifier (duplicate / not duplicate)

**Model Architecture**:

```python
class DeduplicationClassifier(nn.Module):
    """
    Neural network for vulnerability deduplication.

    Input: Concatenated embeddings + metadata
    Output: Duplicate probability
    """

    def __init__(self):
        super().__init__()

        # Embedding dimension: 768 (CodeBERT) × 2 (pairwise)
        # Metadata dimension: 20 (scanner, severity, location features)
        input_dim = (768 * 2) + 20

        self.network = nn.Sequential(
            nn.Linear(input_dim, 512),
            nn.ReLU(),
            nn.Dropout(0.3),

            nn.Linear(512, 256),
            nn.ReLU(),
            nn.Dropout(0.3),

            nn.Linear(256, 128),
            nn.ReLU(),

            nn.Linear(128, 1),
            nn.Sigmoid()
        )

    def forward(self, embedding1, embedding2, metadata):
        # Concatenate embeddings
        combined = torch.cat([embedding1, embedding2, metadata], dim=1)

        # Predict duplicate probability
        return self.network(combined)
```

### Training Data

**Data Collection**:
- 10,000+ manually verified deduplication pairs
- 100,000+ rule-based deduplication results
- Cross-scanner findings (Slither + Aderyn + Semgrep)

**Features**:
```python
features = {
    # Embeddings (768 × 2 = 1536 dims)
    "embedding1": code_embedding1,
    "embedding2": code_embedding2,

    # Metadata (20 dims)
    "scanner_match": 1 if scanner1 == scanner2 else 0,
    "same_file": 1 if file1 == file2 else 0,
    "line_distance": abs(line1 - line2),
    "severity_match": 1 if severity1 == severity2 else 0,
    "pattern_match": 1 if pattern1 == pattern2 else 0,
    # ... 15 more features
}
```

### Deliverables

- [ ] Training dataset creation
- [ ] Model training pipeline
- [ ] Model evaluation (precision/recall)
- [ ] A/B testing framework
- [ ] Continuous learning loop

---

## Phase 3: Advanced Semantic Analysis (Q4 2026)

### Objective

Deep semantic understanding: dataflow analysis, intent detection, behavior modeling.

### Capabilities

**1. Dataflow-Aware Embeddings**:
```python
# Understand that these are different despite similar syntax:

# Safe (no vulnerability):
balances[msg.sender] -= amount;
require(msg.sender.call{value: amount}(""));

# Vulnerable (reentrancy):
msg.sender.call{value: amount}("");
balances[msg.sender] -= amount;  # State change AFTER external call
```

**2. Intent Detection**:
```python
# Detect intent: "transfer tokens"
# Match across different implementations:

# ERC20 style
balances[from] -= amount;
balances[to] += amount;

# Alternative implementation
mapping[from].balance = mapping[from].balance - amount;
mapping[to].balance = mapping[to].balance + amount;
```

**3. Behavior Modeling**:
- Execution trace analysis
- State change patterns
- Attack vector identification

### Technology

- **GraphCodeBERT**: AST + dataflow aware
- **Code2Vec**: Program embeddings
- **Custom models**: Fine-tuned on smart contract vulnerabilities

---

## Migration Strategy

### Hybrid Approach (Q1-Q2 2026)

Combine rule-based + semantic fingerprinting:

```python
def hybrid_deduplication(finding1, finding2) -> tuple[bool, float]:
    """
    Hybrid deduplication using both rule-based and semantic approaches.

    Returns:
        (is_duplicate, confidence_score)
    """
    # Strategy 1: Rule-based (exact match)
    if finding1.code_hash == finding2.code_hash:
        return (True, 1.0)  # 100% confidence

    # Strategy 2: Semantic similarity
    semantic_sim = calculate_semantic_similarity(
        finding1.semantic_embedding,
        finding2.semantic_embedding
    )

    if semantic_sim > 0.90:
        return (True, 0.95)  # High confidence

    if semantic_sim > 0.80:
        # Strategy 3: ML classifier
        ml_confidence = ml_model.predict(finding1, finding2)
        return (ml_confidence > 0.7, ml_confidence)

    return (False, 1 - semantic_sim)
```

### Gradual Rollout

1. **Phase 1a**: Semantic embeddings for storage only (no deduplication logic)
2. **Phase 1b**: Semantic similarity search (read-only, comparison with rule-based)
3. **Phase 2a**: Hybrid deduplication (rule-based primary, semantic fallback)
4. **Phase 2b**: A/B testing (50% traffic to semantic)
5. **Phase 3**: Semantic-first with rule-based fallback

---

## Success Metrics

| Phase | Metric | Target | Current |
|-------|--------|--------|---------|
| Phase 0 (Rule-Based) | Pattern match accuracy | 100% | ✅ 100% |
| | Collision rate | <1% | ✅ 0% |
| Phase 1 (Semantic) | Semantic match accuracy | >85% | - |
| | Fuzzy deduplication recall | >90% | - |
| Phase 2 (ML) | Deduplication precision | >95% | - |
| | False positive rate | <5% | - |
| Phase 3 (Advanced) | Intent detection accuracy | >80% | - |
| | Dataflow match accuracy | >75% | - |

---

## Budget & Resources

### Infrastructure Costs

- **Vector Database** (Qdrant Cloud): $200/month
- **ML Training** (GPU): $500/month (Q3 2026)
- **Model Hosting**: $100/month
- **Total Year 1**: ~$9,600

### Human Resources

- **ML Engineer** (6 months, Q2-Q3 2026): Model training, evaluation
- **Backend Engineer** (3 months): Integration, API development
- **Data Scientist** (3 months): Training data preparation, evaluation

---

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Semantic accuracy <85% | High | Keep rule-based as primary, semantic as fallback |
| High latency (>100ms) | Medium | Pre-compute embeddings, optimize vector search |
| Storage costs | Low | Compress embeddings, tiered storage |
| Model drift | Medium | Continuous evaluation, retraining pipeline |

---

## References

- **CodeBERT**: https://arxiv.org/abs/2002.08155
- **GraphCodeBERT**: https://arxiv.org/abs/2009.08366
- **pgvector**: https://github.com/pgvector/pgvector
- **Qdrant**: https://qdrant.tech/

---

**Status**: ✅ Roadmap Defined
**Owner**: Intelligence Layer Team / ML Team
**Next Review**: Q1 2026
