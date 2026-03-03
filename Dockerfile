# ---- Builder stage ---------------------------------------------------------
# We install dependencies into a virtualenv using uv, then copy only the venv + app
# into a smaller runtime image.
FROM python:3.14-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    # Codespaces/Docker builds can have flaky throughput for large ML wheels.
    # Increase uv timeout + retries to avoid failing mid-download.
    UV_HTTP_TIMEOUT=600 \
    UV_HTTP_RETRIES=5 \
    # Reducing concurrency can make downloads more reliable in constrained environments.
    UV_CONCURRENT_DOWNLOADS=2

WORKDIR /app

# Minimal build deps. Some Python wheels (ML libs) may need compilation.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast dependency manager)
RUN pip install --no-cache-dir uv

# Copy only dependency manifests first (better Docker layer caching)
COPY embeddings/pyproject.toml embeddings/uv.lock /app/embeddings/

# Install dependencies (locked). --frozen ensures uv.lock must match.
RUN cd /app/embeddings && uv sync --frozen --no-dev

# Copy the actual app code last (so dependency layer can stay cached)
COPY embeddings /app/embeddings


# ---- Runtime stage ---------------------------------------------------------
FROM python:3.14-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/opt/venv/bin:$PATH" \
    # Default cache directories for model weights (we will mount volumes here in compose)
    SENTENCE_TRANSFORMERS_HOME=/data/st \
    HF_HOME=/data/hf

WORKDIR /app/embeddings

# Create a non-root user (security best practice)
RUN useradd -m -u 10001 appuser \
    && mkdir -p /data/st /data/hf \
    && chown -R appuser:appuser /data

# Copy venv and app from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /app/embeddings /app/embeddings

USER appuser

EXPOSE 8000

# Healthcheck uses readiness (only healthy when model is loaded)
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/ready').read()" || exit 1

# Run uvicorn (prod default). If they want workers later we can add it.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]