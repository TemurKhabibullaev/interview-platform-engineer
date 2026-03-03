# Embeddings API

A FastAPI service that converts text into vector embeddings using [`sentence-transformers`](https://www.sbert.net/).


## Requirements

- [uv](https://docs.astral.sh/uv/) — Python package manager
- Python 3.14 (automatically managed by uv)


## Quickstart (Docker-Recommended)
> First startup may take ~30–60 seconds due to model download.

From the repo root:

```bash
docker compose up --build
```

Service will be available at:

* http://localhost:8000/health - (liveness)
* http://localhost:8000/ready - (readiness; returns 200 only after the model is loaded)
* http://localhost:8000/docs - (Swagger UI)

## Cleanup

Stop Containers:
```bash
docker compose down
```

Remove cached model volumes (forces re-download):
```bash
docker compose down -v
```
 Remove all stopped containers, networks not used by at least one container, images without at least one container associated to them, and all build cache:
 
```bash
docker system prune -a
```

## Quickstart (Local dev)

From the repo root:

```bash
make dev
```

Or manually:

```bash
uv sync
uv run uvicorn main:app --reload
```
The API will be available at http://localhost:8000.
On first startup the model (all-MiniLM-L6-v2, ~90MB) is downloaded from HuggingFace and cached locally. Subsequent starts are instant.

## Endpoints
- `GET /health`  → liveness (process up)
- `GET /ready`   → readiness (model loaded)
- `POST /embed`  → returns embeddings for text(s)

## Example Request

```bash
curl -s -X POST http://localhost:8000/embed \
  -H "Content-Type: application/json" \
  -d '{"text":"hello"}' | head
```

## Example Response

```json
{
  "embeddings": [[0.021, -0.045, ...]],
  "model": "all-MiniLM-L6-v2",
  "dimensions": 384
}
```

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
1. Model loads at startup

The embedding model is loaded during FastAPI startup (lifespan event):
* Avoids per-request load latency
* Ensures readiness blocks traffic until fully initialized
* Fails fast if model initialization fails

2. Separate Liveness and Readiness

* /health → verifies process is running
* /ready → verifies model successfully loaded

This mirrors production deployment patterns (e.g., Kubernetes probes).

3. Multi-stage Docker Build

The Dockerfile:
* Uses a builder stage
* Installs locked dependencies (uv.lock)
* Improves Docker layer caching
* Produces a smaller runtime image

4. Non-root Runtime Container

The application runs as a non-root user (appuser) for improved container security.

5. Persistent Model Caching

Docker volumes persist model weights:
* Prevents repeated downloads
* Speeds up local development
* Improves reliability in constrained environments


## Model Caching

The container uses Docker volumes to persist model weights across restarts and rebuilds:

- `SENTENCE_TRANSFORMERS_HOME=/data/st`
- `HF_HOME=/data/hf`

This prevents re-downloading large models on every run and improves local development speed.

## Interactive Documentation

FastAPI provides built-in interactive API documentation:

| UI         | URL                         |
| ---------- | --------------------------- |
| Swagger UI | http://localhost:8000/docs  |
| ReDoc      | http://localhost:8000/redoc |


## Example API Usage

### `GET /health`

```json
{"status": "ok"}
```

POST /embed

Request:
{
  "text": "Hello, world!"
}

Batch request:
{
  "text": ["Hello, world!", "FastAPI is great"]
}

Response:
{
  "embeddings": [[0.021, -0.045, ...]],
  "model": "all-MiniLM-L6-v2",
  "dimensions": 384
}