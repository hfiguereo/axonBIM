# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de ``IfcSession`` y sus helpers singleton."""

from __future__ import annotations

from axonbim.ifc.session import IfcSession, get_session, reset_session


def test_create_new_has_spatial_hierarchy() -> None:
    session = IfcSession.create_new(project_name="Pruebas")
    assert session.file.by_type("IfcProject")
    assert session.file.by_type("IfcSite")
    assert session.file.by_type("IfcBuilding")
    assert session.file.by_type("IfcBuildingStorey")
    assert session.project.Name == "Pruebas"


def test_body_context_is_model_body() -> None:
    session = IfcSession.create_new()
    assert session.body_context.ContextIdentifier == "Body"


def test_get_session_is_singleton() -> None:
    reset_session()
    first = get_session()
    second = get_session()
    assert first is second


def test_reset_session_creates_new_instance() -> None:
    reset_session()
    first = get_session()
    reset_session()
    second = get_session()
    assert first is not second
