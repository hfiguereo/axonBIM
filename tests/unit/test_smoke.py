# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Smoke tests del scaffolding (Sprint 1.0).

Verifican que el paquete importa, que los subpaquetes estan en su sitio
y que la version publica es coherente con ``pyproject.toml``.
"""

from __future__ import annotations

import importlib

import axonbim
from axonbim import logging_config


def test_version_exposed() -> None:
    assert axonbim.__version__
    assert isinstance(axonbim.__version__, str)


def test_subpackages_importable() -> None:
    for name in (
        "axonbim.rpc",
        "axonbim.handlers",
        "axonbim.geometry",
        "axonbim.ifc",
        "axonbim.drawing",
        "axonbim.persistence",
        "axonbim.logging_config",
    ):
        importlib.import_module(name)


def test_logging_config_idempotent() -> None:
    logging_config.configure("DEBUG")
    logging_config.configure("DEBUG")
