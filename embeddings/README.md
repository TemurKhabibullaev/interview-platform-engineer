# Embeddings API

A FastAPI service that converts text into vector embeddings using [`sentence-transformers`](https://www.sbert.net/).


## Requirements

- [uv](https://docs.astral.sh/uv/) — Python package manager
- Python 3.14 (automatically managed by uv)


## Quickstart (Docker)

From the repo root:

```bash
docker compose up --build
```
To stop:
```bash
docker compose down
```

Then visit:

* http://localhost:8000/health - (liveness)
* http://localhost:8000/ready - (readiness; returns 200 only after the model is loaded)
* http://localhost:8000/docs - (Swagger UI)

## Model caching (important)
The container uses Docker volumes to persist model weights across restarts/rebuilds:

* SENTENCE_TRANSFORMERS_HOME=/data/st
* HF_HOME=/data/hf

This prevents re-downloading the model each time you run the service.

## Quickstart (Local dev)

From the repo root:

```bash
make dev
```

SENTENCE_TRANSFORMERS_HOME=/data/st

HF_HOME=/data/hf

This prevents re-downloading the model each time you run the service.

Quickstart (Local dev)

From the repo root:

make dev
## Running Locally

### 1. Install dependencies

```bash
uv sync
```

### 2. Start the server

```bash
uv run uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`.

> On first startup the model (`all-MiniLM-L6-v2`, ~90 MB) is downloaded from HuggingFace and cached locally. Subsequent starts are instant.

## Interactive Docs

FastAPI ships with built-in docs:

| UI         | URL                         |
| ---------- | --------------------------- |
| Swagger UI | http://localhost:8000/docs  |
| ReDoc      | http://localhost:8000/redoc |

## Endpoints
- `GET /health`  → liveness (process up)
- `GET /ready`   → readiness (model loaded)
- `POST /embed`  → returns embeddings for text(s)

## Configuration

The service is configurable via environment variables:

- `MODEL_NAME`  
  Default: `all-MiniLM-L6-v2`  
  Allows swapping embedding models without changing code.

- `SENTENCE_TRANSFORMERS_HOME`  
  Default (in container): `/data/st`  
  Controls where SentenceTransformer caches model weights.

- `HF_HOME`  
  Default (in container): `/data/hf`  
  Controls HuggingFace cache location.

These are set automatically in `docker-compose.yml`, but can be overridden.

## Design Decisions

### 1. Model loads at startup
The embedding model is loaded during application startup (FastAPI lifespan).
This ensures:

- No per-request loading overhead
- Readiness is blocked until the model is fully initialized
- Failure to load the model fails fast during startup

### 2. Separate liveness and readiness

- `/health` → liveness (process is running)
- `/ready` → readiness (model successfully loaded)

This separation mirrors production patterns (e.g., Kubernetes probes).

### 3. Multi-stage Docker build

The Dockerfile uses a builder stage to:

- Install dependencies using a locked `uv.lock`
- Improve layer caching
- Produce a smaller runtime image

### 4. Non-root container

The runtime container runs as a non-root user (`appuser`) for improved security.

### 5. Persistent model caching

Docker volumes are used to persist model weights:

- Prevents re-downloading large models
- Speeds up local development
- Improves reliability in constrained environments

### `GET /health`

Returns service status.

```json
{"status": "ok"}
```

---

### `POST /embed`

Convert one or more strings into vectors.

**Request body**

```json
{
  "text": "Hello, world!"
}
```

or a batch:

```json
{
  "text": ["Hello, world!", "FastAPI is great"]
}
```

**Response**

```json
{
  "embeddings": [[0.021, -0.045, ...]],
  "model": "all-MiniLM-L6-v2",
  "dimensions": 384
}
```

## Example curl

```bash
curl -X POST http://localhost:8000/embed \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, world!"}'
```
