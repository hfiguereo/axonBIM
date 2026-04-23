.PHONY: help install sync lint format typecheck test test-unit test-integration test-cov \
        start run run-dev run-backend run-godot gdlint gdformat clean distclean

UV ?= uv
# Binario oficial en ~/.local/bin/godot (ver scripts/dev/install_godot_official.sh); si no existe, usa `godot` del PATH.
GODOT ?= $(shell test -x "$(HOME)/.local/bin/godot" && echo "$(HOME)/.local/bin/godot" || command -v godot 2>/dev/null || echo godot)

help:
	@echo "AxonBIM - targets disponibles:"
	@echo "  install         - uv sync (instala deps del lockfile)"
	@echo "  sync            - alias de install"
	@echo "  lint            - ruff check + gdlint"
	@echo "  format          - ruff format + gdformat"
	@echo "  typecheck       - mypy --strict src/"
	@echo "  test            - pytest -q"
	@echo "  test-unit       - pytest tests/unit -q"
	@echo "  test-integration- pytest tests/integration -q"
	@echo "  test-cov        - pytest con cobertura (falla si < 80%)"
	@echo "  start / run     - un comando: uv sync + backend + Godot (recomendado)"
	@echo "  run-backend     - solo Python RPC (sin Godot; puerto TCP 5799)"
	@echo "  run-godot       - solo Godot (en otra terminal con backend ya en marcha)"
	@echo "  gdlint          - gdtoolkit lint sobre frontend/"
	@echo "  gdformat        - gdtoolkit format sobre frontend/"
	@echo "  clean           - limpia artefactos de build"
	@echo "  distclean       - clean + elimina .venv"

install sync:
	$(UV) sync --all-extras

lint:
	$(UV) run ruff check .
	$(UV) run ruff format --check .
	@command -v gdlint >/dev/null 2>&1 && gdlint frontend/ || echo "gdlint no instalado (pipx install gdtoolkit)"

format:
	$(UV) run ruff format .
	$(UV) run ruff check --fix .
	@command -v gdformat >/dev/null 2>&1 && gdformat frontend/ || echo "gdformat no instalado (pipx install gdtoolkit)"

typecheck:
	$(UV) run mypy --strict src/

test:
	$(UV) run pytest -q

test-unit:
	$(UV) run pytest tests/unit -q

test-integration:
	$(UV) run pytest tests/integration -q

test-cov:
	$(UV) run pytest -q --cov=src/axonbim --cov-report=term-missing --cov-fail-under=80

start run run-dev:
	bash start

run-backend:
	@echo ""
	@echo "=== AxonBIM: solo backend (no abre ventana de Godot) ==="
	@echo "    RPC TCP 127.0.0.1:5799 + socket Unix. Detener: Ctrl+C."
	@echo "    App completa: make run    |    Frontend aparte: make run-godot"
	@echo ""
	$(UV) run python -u -m axonbim --tcp

run-godot:
	@echo ""
	@echo "=== AxonBIM: solo Godot (necesita backend en otra terminal salvo que ya este corriendo) ==="
	@echo ""
	AXONBIM_RPC_PORT=5799 $(GODOT) --path frontend

gdlint:
	@command -v gdlint >/dev/null 2>&1 && gdlint frontend/ || (echo "instala: pipx install gdtoolkit" && exit 1)

gdformat:
	@command -v gdformat >/dev/null 2>&1 && gdformat frontend/ || (echo "instala: pipx install gdtoolkit" && exit 1)

clean:
	rm -rf build/ dist/ *.egg-info .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete

distclean: clean
	rm -rf .venv/
