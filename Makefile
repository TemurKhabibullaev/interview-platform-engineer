SVC_DIR=embeddings
IMAGE=embeddings-api:dev
PORT?=8000

.PHONY: help dev test docker-build docker-run up down logs clean

help:
	@echo "Targets:"
	@echo "  make dev         - run locally with uv (hot reload)"
	@echo "  make test        - smoke test against running server"
	@echo "  make docker-build"
	@echo "  make docker-run"
	@echo "  make up          - docker compose up"
	@echo "  make down        - docker compose down"
	@echo "  make logs        - docker compose logs"
	@echo "  make clean       - remove docker artifacts"

dev:
	cd $(SVC_DIR) && uv sync
	cd $(SVC_DIR) && uv run uvicorn main:app --reload --host 0.0.0.0 --port $(PORT)

test:
	@curl -fsS http://localhost:$(PORT)/health >/dev/null
	@curl -fsS -X POST http://localhost:$(PORT)/embed \
		-H "Content-Type: application/json" \
		-d '{"text":"hello world"}' >/dev/null
	@echo "OK"

docker-build:
	docker build -t $(IMAGE) .

docker-run:
	docker run --rm -p $(PORT):8000 $(IMAGE)

up:
	docker compose up --build

down:
	docker compose down

logs:
	docker compose logs -f

clean:
	docker compose down -v || true
	docker rmi $(IMAGE) || true

