import os # read configuration from environment variables
from contextlib import asynccontextmanager
from typing import Union

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from sentence_transformers import SentenceTransformer

model: Union[SentenceTransformer, None] = None
# -----------------------------
# Runtime configuration
# -----------------------------
# Change the model WITHOUT touching code.
# Example: MODEL_NAME="all-MiniLM-L6-v2" or "sentence-transformers/all-mpnet-base-v2"
MODEL_NAME = os.getenv("MODEL_NAME", "all-MiniLM-L6-v2")

# SentenceTransformer downloads model weights and caches them on disk.
# In Docker, we’ll mount a volume to this folder so the model doesn't re-download every run.
CACHE_DIR = os.getenv("SENTENCE_TRANSFORMERS_HOME")  # optional; can be None

@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    # Load the embedding model once during startup.
    # This avoids downloading/loading the model on every request.
    # cache_folder lets us control where the model weights are stored (important for Docker caching).
    model = SentenceTransformer(MODEL_NAME, cache_folder=CACHE_DIR)
    yield
    model = None


app = FastAPI(
    title="Embeddings API",
    description="Convert text into vector embeddings using sentence-transformers.",
    version="0.1.0",
    lifespan=lifespan,
)


class EmbedRequest(BaseModel):
    text: str | list[str]


class EmbedResponse(BaseModel):
    embeddings: list[list[float]]
    model: str
    dimensions: int


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    """
    Readiness check: returns 200 only when the model is loaded and we can serve traffic.
    In Kubernetes, this would map to a readinessProbe.
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "ready", "model": MODEL_NAME}


@app.post("/embed", response_model=EmbedResponse)
def embed(request: EmbedRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    texts = request.text if isinstance(request.text, list) else [request.text]
    vectors = model.encode(texts, convert_to_numpy=True).tolist()

    return EmbedResponse(
        embeddings=vectors,
        model=MODEL_NAME,
        dimensions=len(vectors[0]),
    )
