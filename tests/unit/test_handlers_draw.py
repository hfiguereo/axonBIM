# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests unitarios de handlers ``draw.*``."""

from __future__ import annotations

import ezdxf
import pytest
from pydantic import ValidationError

from axonbim.drawing.layer_ids import arch_layer_names
from axonbim.handlers import draw as draw_handlers
from axonbim.handlers import ifc as ifc_handlers
from axonbim.ifc.session import reset_session
from axonbim.rpc.dispatcher import Dispatcher


@pytest.fixture(autouse=True)
def _fresh_session() -> None:
    reset_session()


async def test_draw_ortho_snapshot_returns_lines_for_top_view() -> None:
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 6.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    out = await draw_handlers.ortho_snapshot({"view": "top", "width_px": 900, "height_px": 600})
    assert "projection_engine" not in out
    assert out["view"] == "top"
    assert out["line_count"] > 0
    assert out["width_px"] == 900
    assert out["height_px"] == 600
    assert len(out["world_bounds_uv"]) == 4
    assert out["meters_per_px"] > 0.0


async def test_draw_ortho_snapshot_rejects_unknown_fields() -> None:
    with pytest.raises(ValidationError):
        await draw_handlers.ortho_snapshot({"view": "top", "foo": 1})


async def test_draw_ortho_snapshot_empty_model_uses_workspace_bounds() -> None:
    out = await draw_handlers.ortho_snapshot({"view": "top", "width_px": 900, "height_px": 600})
    assert out["view"] == "top"
    assert out["line_count"] == 0
    assert len(out["world_bounds_uv"]) == 4
    b = out["world_bounds_uv"]
    assert b[0] < b[2] and b[1] < b[3]
    assert out["meters_per_px"] > 0.0
    assert out["lines_px"] == []


async def test_draw_ortho_snapshot_persists_view_state() -> None:
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 2.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    out = await draw_handlers.ortho_snapshot(
        {"view": "front", "view_id": "view2d_42", "requested_scale_m_per_px": 0.5}
    )
    state = out["view_state"]
    assert state["view"] == "front"
    assert state["requested_scale_m_per_px"] == 0.5
    assert state["cut_plane_m"] == 0.0


async def test_draw_ortho_snapshot_accepts_view_range_and_returns_it() -> None:
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 3.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    out = await draw_handlers.ortho_snapshot(
        {
            "view": "top",
            "view_range": {
                "cut_plane_m": 1.2,
                "top_m": 3.0,
                "bottom_m": 0.0,
                "depth_m": 1.2,
            },
        }
    )
    vr = out["view_range"]
    assert vr["cut_plane_m"] == 1.2
    assert vr["top_m"] == 3.0
    assert vr["bottom_m"] == 0.0


async def test_draw_ortho_snapshot_top_view_range_can_hide_geometry() -> None:
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 3.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    visible = await draw_handlers.ortho_snapshot(
        {"view": "top", "view_range": {"cut_plane_m": 1.2, "top_m": 3.0, "bottom_m": 0.0, "depth_m": 1.2}}
    )
    hidden = await draw_handlers.ortho_snapshot(
        {"view": "top", "view_range": {"cut_plane_m": 3.2, "top_m": 3.3, "bottom_m": 3.1, "depth_m": 0.0}}
    )
    assert visible["line_count"] > 0
    assert hidden["line_count"] == 0


async def test_register_draw_handlers_exposes_ortho_snapshot() -> None:
    disp = Dispatcher()
    draw_handlers.register(disp)
    assert "draw.ortho_snapshot" in disp.registered_methods()
    assert "draw.export_dxf_walls" in disp.registered_methods()


async def test_draw_export_dxf_walls_writes_file(tmp_path) -> None:
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 2.0, "y": 1.0},
            "height": 2.5,
            "thickness": 0.15,
        }
    )
    out_path = tmp_path / "walls_top.dxf"
    out = await draw_handlers.export_dxf_walls({"out_path": str(out_path), "view": "top"})
    assert out["segment_count"] > 0
    assert out_path.is_file()
    assert out_path.stat().st_size > 32
    doc = ezdxf.readfile(str(out_path))
    for layer_name in arch_layer_names():
        assert layer_name in doc.layers


async def test_draw_ortho_snapshot_south_mirrors_u_bounds_vs_north() -> None:
    """Sur invierte u respecto a Norte para alinear el vectorial 2D con la cámara Godot (+Y)."""
    await ifc_handlers.create_wall(
        {
            "p1": {"x": 0.0, "y": 0.0},
            "p2": {"x": 6.0, "y": 0.0},
            "height": 3.0,
            "thickness": 0.2,
        }
    )
    north = await draw_handlers.ortho_snapshot({"view": "north", "width_px": 900, "height_px": 600})
    south = await draw_handlers.ortho_snapshot({"view": "south", "width_px": 900, "height_px": 600})
    assert north["view"] == "north"
    assert south["view"] == "south"
    nu = north["world_bounds_uv"]
    su = south["world_bounds_uv"]
    cn = (float(nu[0]) + float(nu[2])) * 0.5
    cs = (float(su[0]) + float(su[2])) * 0.5
    assert cn > 0.0
    assert cs < 0.0
    assert abs(cn + cs) < 0.05
