.PHONY: help install sync lint format typecheck test test-unit test-integration test-cov \
        run-backend run-godot gdlint gdformat clean distclean

UV ?= uv
GODOT ?= godot

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
	@echo "  run-backend     - python -m axonbim"
	@echo "  run-godot       - abre el proyecto Godot"
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

run-backend:
	$(UV) run python -m axonbim

run-godot:
	$(GODOT) --path frontend

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
