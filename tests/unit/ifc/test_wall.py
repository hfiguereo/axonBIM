# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de creacion de ``IfcWall`` + round-trip de lectura/escritura."""

from __future__ import annotations

from pathlib import Path

import ifcopenshell
import pytest

from axonbim.ifc.session import IfcSession
from axonbim.ifc.wall import create_wall


@pytest.fixture
def session() -> IfcSession:
    return IfcSession.create_new(project_name="WallTests")


def test_create_wall_returns_guid_and_mesh(session: IfcSession) -> None:
    result = create_wall(session, (0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    assert len(result.guid) == 22
    assert result.mesh.triangle_count == 12


def test_wall_is_contained_in_storey(session: IfcSession) -> None:
    create_wall(session, (0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    walls = session.file.by_type("IfcWall")
    assert len(walls) == 1
    containment = walls[0].ContainedInStructure
    assert containment
    assert containment[0].RelatingStructure == session.storey


def test_two_walls_get_unique_names(session: IfcSession) -> None:
    a = create_wall(session, (0.0, 0.0, 0.0), (3.0, 0.0, 0.0), height=3.0, thickness=0.2)
    b = create_wall(session, (0.0, 1.0, 0.0), (3.0, 1.0, 0.0), height=3.0, thickness=0.2)
    assert a.guid != b.guid
    walls = session.file.by_type("IfcWall")
    names = {w.Name for w in walls}
    assert names == {"Wall-001", "Wall-002"}


def test_explicit_name_overrides_auto_numbering(session: IfcSession) -> None:
    result = create_wall(
        session,
        (0.0, 0.0, 0.0),
        (3.0, 0.0, 0.0),
        height=3.0,
        thickness=0.2,
        name="Fachada-Norte",
    )
    wall = session.file.by_guid(result.guid)
    assert wall.Name == "Fachada-Norte"


def test_wall_has_shape_representation(session: IfcSession) -> None:
    result = create_wall(session, (0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    wall = session.file.by_guid(result.guid)
    assert wall.Representation is not None
    representations = wall.Representation.Representations
    assert representations
    assert any(r.RepresentationIdentifier == "Body" for r in representations)


def test_wall_roundtrip_write_and_reopen(session: IfcSession, tmp_path: Path) -> None:
    result = create_wall(session, (0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=3.0, thickness=0.2)
    out = tmp_path / "wall_roundtrip.ifc"
    session.save(out)
    assert out.stat().st_size > 0

    reopened = ifcopenshell.open(str(out))
    walls = reopened.by_type("IfcWall")
    assert len(walls) == 1
    assert walls[0].GlobalId == result.guid


def test_invalid_dimensions_rejected(session: IfcSession) -> None:
    with pytest.raises(ValueError, match="height"):
        create_wall(session, (0.0, 0.0, 0.0), (4.0, 0.0, 0.0), height=-1.0, thickness=0.2)
