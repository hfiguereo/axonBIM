# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Handlers del dominio ``draw.*``: snapshots ortogonales para vistas 2D."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

from axonbim.drawing.dxf_walls import write_wall_projection_dxf
from axonbim.geometry import topo_registry
from axonbim.geometry.meshing import Mesh, wall_mesh_for_spec
from axonbim.geometry.wall_spec import WallSpec
from axonbim.geometry.workspace_xy import WorkspaceXYHalfExtents
from axonbim.ifc.session import get_session
from axonbim.rpc.dispatcher import Dispatcher, RpcError
from axonbim.rpc.models import ErrorCode

_DEFAULT_WIDTH_PX = 1280
_DEFAULT_HEIGHT_PX = 800
_DEFAULT_MARGIN_PX = 24
_WORLD_EPS = 1e-9
_MIN_Z_SPAN_M: float = 1e-4


class OrthoSnapshotParams(BaseModel):
    """Parámetros de ``draw.ortho_snapshot``."""

    model_config = ConfigDict(extra="forbid")

    view: Literal["top", "front", "right", "north", "south", "east", "west"] = "top"
    width_px: int = Field(default=_DEFAULT_WIDTH_PX, ge=256, le=4096)
    height_px: int = Field(default=_DEFAULT_HEIGHT_PX, ge=256, le=4096)
    margin_px: int = Field(default=_DEFAULT_MARGIN_PX, ge=0, le=256)
    view_id: str | None = Field(default=None, min_length=1)
    requested_scale_m_per_px: float | None = Field(default=None, gt=0.0)
    view_range: dict[str, float] | None = None


class ExportDxfWallsParams(BaseModel):
    """Parámetros de ``draw.export_dxf_walls``."""

    model_config = ConfigDict(extra="forbid")

    out_path: str = Field(min_length=1, max_length=8192)
    view: Literal["top", "front", "right"] = "top"
    view_range: dict[str, float] | None = None


def _normalized_view_range(view: str, raw: dict[str, float] | None) -> dict[str, float]:
    if raw is None:
        if view == "top":
            return {
                "cut_plane_m": 1.2,
                "top_m": 3.0,
                "bottom_m": 0.0,
                "depth_m": 1.2,
            }
        return {
            "cut_plane_m": 0.0,
            "top_m": 10.0,
            "bottom_m": -10.0,
            "depth_m": 10.0,
        }
    cut = float(raw.get("cut_plane_m", 1.2))
    top = float(raw.get("top_m", 3.0))
    bottom = float(raw.get("bottom_m", 0.0))
    depth = float(raw.get("depth_m", 1.2))
    if top < bottom:
        top, bottom = bottom, top
    cut = max(cut, bottom)
    cut = min(cut, top)
    depth = max(depth, 0.0)
    return {
        "cut_plane_m": cut,
        "top_m": top,
        "bottom_m": bottom,
        "depth_m": depth,
    }


def _segment_passes_view_range_top(z1: float, z2: float, view_range: dict[str, float]) -> bool:
    cut = view_range["cut_plane_m"]
    top = view_range["top_m"]
    bottom = view_range["bottom_m"]
    depth = view_range["depth_m"]
    low = max(bottom, cut - depth)
    high = top
    seg_low = min(z1, z2)
    seg_high = max(z1, z2)
    return not (seg_high < low or seg_low > high)


def _project_point(view: str, x: float, y: float, z: float) -> tuple[float, float]:
    """Proyecta (x,y,z) mundo a (u,v) metros en el plano de dibujo 2D.

    Alineado con las cámaras ortográficas de Godot (Z arriba, +Y = norte del proyecto):
    ``north`` equivale al antiguo ``front`` (cámara en -Y); ``south`` es la elevación
    opuesta (cámara en +Y, eje horizontal u invertido). ``west`` equivale a ``right``
    (cámara en +X); ``east`` invierte u respecto a ``west``.
    """
    if view == "top":
        return (x, y)
    if view in ("front", "north"):
        return (x, z)
    if view == "south":
        return (-x, z)
    if view in ("right", "west"):
        return (y, z)
    if view == "east":
        return (-y, z)
    return (y, z)


def _append_edges_from_tri_mesh(
    view: str,
    mesh: Mesh,
    view_range: dict[str, float],
    lines: list[tuple[float, float, float, float]],
    seen: set[tuple[int, int, int, int]],
) -> None:
    """Proyecta aristas de triángulos a segmentos UV, deduplicados en ``seen``."""
    vertices = mesh.vertices
    indices = mesh.indices
    tri_count = len(indices) // 3
    for tri_idx in range(tri_count):
        i0 = indices[tri_idx * 3 + 0]
        i1 = indices[tri_idx * 3 + 1]
        i2 = indices[tri_idx * 3 + 2]
        p3 = []
        for vid in (i0, i1, i2):
            base = vid * 3
            p3.append((vertices[base + 0], vertices[base + 1], vertices[base + 2]))
        pairs = ((0, 1), (1, 2), (2, 0))
        for a, b in pairs:
            if view == "top" and not _segment_passes_view_range_top(
                p3[a][2], p3[b][2], view_range
            ):
                continue
            u1, v1 = _project_point(view, p3[a][0], p3[a][1], p3[a][2])
            u2, v2 = _project_point(view, p3[b][0], p3[b][1], p3[b][2])
            key = tuple(
                sorted(
                    (
                        (round(u1 * 1000.0), round(v1 * 1000.0)),
                        (round(u2 * 1000.0), round(v2 * 1000.0)),
                    )
                )
            )
            flat_key = (key[0][0], key[0][1], key[1][0], key[1][1])
            if flat_key in seen:
                continue
            seen.add(flat_key)
            lines.append((u1, v1, u2, v2))


def _build_lines_world(
    view: str,
    specs: dict[str, WallSpec],
    view_range: dict[str, float],
) -> list[tuple[float, float, float, float]]:
    """Segmentos UV en metros desde la malla analítica de caja (alineada con Godot)."""
    lines: list[tuple[float, float, float, float]] = []
    seen: set[tuple[int, int, int, int]] = set()
    for guid, spec in specs.items():
        mesh = wall_mesh_for_spec(
            spec,
            parent_guid=guid,
        )
        _append_edges_from_tri_mesh(view, mesh, view_range, lines, seen)
    return lines


def _fit_to_pixels(
    lines_world: list[tuple[float, float, float, float]],
    *,
    width_px: int,
    height_px: int,
    margin_px: int,
) -> tuple[list[list[float]], list[float], float]:
    if not lines_world:
        return ([], [0.0, 0.0, 1.0, 1.0], 1.0)
    us = [x for line in lines_world for x in (line[0], line[2])]
    vs = [y for line in lines_world for y in (line[1], line[3])]
    min_u = min(us)
    max_u = max(us)
    min_v = min(vs)
    max_v = max(vs)
    span_u = max(max_u - min_u, _WORLD_EPS)
    span_v = max(max_v - min_v, _WORLD_EPS)
    inner_w = max(1, width_px - margin_px * 2)
    inner_h = max(1, height_px - margin_px * 2)
    scale_px_per_m = min(inner_w / span_u, inner_h / span_v)
    if scale_px_per_m <= 0.0:
        scale_px_per_m = 1.0
    off_x = margin_px + (inner_w - span_u * scale_px_per_m) * 0.5
    off_y = margin_px + (inner_h - span_v * scale_px_per_m) * 0.5

    lines_px: list[list[float]] = []
    for u1, v1, u2, v2 in lines_world:
        x1 = off_x + (u1 - min_u) * scale_px_per_m
        y1 = height_px - (off_y + (v1 - min_v) * scale_px_per_m)
        x2 = off_x + (u2 - min_u) * scale_px_per_m
        y2 = height_px - (off_y + (v2 - min_v) * scale_px_per_m)
        lines_px.append([x1, y1, x2, y2])
    m_per_px = 1.0 / max(scale_px_per_m, _WORLD_EPS)
    return (lines_px, [min_u, min_v, max_u, max_v], m_per_px)


def _workspace_uv_bounds(
    view: str, view_range: dict[str, float], wxy: WorkspaceXYHalfExtents
) -> tuple[float, float, float, float]:
    """Rectángulo (u_min, v_min, u_max, v_max) en metros cuando no hay geometría que encuadre."""
    if view == "top":
        return (-wxy.half_x_m, -wxy.half_y_m, wxy.half_x_m, wxy.half_y_m)
    if view in ("front", "north", "south"):
        z0 = float(view_range["bottom_m"])
        z1 = float(view_range["top_m"])
        if z1 - z0 < _MIN_Z_SPAN_M:
            z1 = z0 + 1.0
        return (-wxy.half_x_m, z0, wxy.half_x_m, z1)
    z0 = float(view_range["bottom_m"])
    z1 = float(view_range["top_m"])
    if z1 - z0 < _MIN_Z_SPAN_M:
        z1 = z0 + 1.0
    return (-wxy.half_y_m, z0, wxy.half_y_m, z1)


def _fit_bounds_to_pixels(
    min_u: float,
    min_v: float,
    max_u: float,
    max_v: float,
    *,
    width_px: int,
    height_px: int,
    margin_px: int,
) -> tuple[list[list[float]], list[float], float]:
    """Encaja un rectángulo UV mundo en píxeles (misma lógica que ``_fit_to_pixels``, sin segmentos)."""
    span_u = max(max_u - min_u, _WORLD_EPS)
    span_v = max(max_v - min_v, _WORLD_EPS)
    inner_w = max(1, width_px - margin_px * 2)
    inner_h = max(1, height_px - margin_px * 2)
    scale_px_per_m = min(inner_w / span_u, inner_h / span_v)
    if scale_px_per_m <= 0.0:
        scale_px_per_m = 1.0
    m_per_px = 1.0 / max(scale_px_per_m, _WORLD_EPS)
    bounds = [min_u, min_v, max_u, max_v]
    return ([], bounds, m_per_px)


async def ortho_snapshot(params: dict[str, Any]) -> dict[str, Any]:
    """Devuelve líneas ortogonales 2D para una vista (proyección analítica de la caja de muro).

    Sin elementos de muro en la sesión, devuelve ``lines_px`` vacío y un encuadre UV
    coherente con el rectángulo de trabajo en planta (``workspace_xy``), para alinear
    el lienzo 2D en Godot antes del primer muro.
    """
    args = OrthoSnapshotParams.model_validate(params)
    specs = topo_registry.all_wall_specs()
    view_range = _normalized_view_range(args.view, args.view_range)
    session = get_session()
    if not specs:
        min_u, min_v, max_u, max_v = _workspace_uv_bounds(args.view, view_range, session.workspace_xy)
        lines_px, bounds_world, m_per_px = _fit_bounds_to_pixels(
            min_u,
            min_v,
            max_u,
            max_v,
            width_px=args.width_px,
            height_px=args.height_px,
            margin_px=args.margin_px,
        )
    else:
        lines_world = _build_lines_world(args.view, specs, view_range)
        lines_px, bounds_world, m_per_px = _fit_to_pixels(
            lines_world,
            width_px=args.width_px,
            height_px=args.height_px,
            margin_px=args.margin_px,
        )
    state: dict[str, float | str] = {}
    if args.view_id is not None:
        state = {
            "view": args.view,
            "meters_per_px": m_per_px,
            "requested_scale_m_per_px": (
                float(args.requested_scale_m_per_px)
                if args.requested_scale_m_per_px is not None
                else m_per_px
            ),
            "width_px": float(args.width_px),
            "height_px": float(args.height_px),
            "cut_plane_m": view_range["cut_plane_m"],
            "top_m": view_range["top_m"],
            "bottom_m": view_range["bottom_m"],
            "depth_m": view_range["depth_m"],
        }
        session.view2d_states[args.view_id] = state
    return {
        "view": args.view,
        "width_px": args.width_px,
        "height_px": args.height_px,
        "lines_px": lines_px,
        "world_bounds_uv": bounds_world,
        "meters_per_px": m_per_px,
        "line_count": len(lines_px),
        "view_state": state,
        "view_range": view_range,
    }


async def export_dxf_walls(params: dict[str, Any]) -> dict[str, Any]:
    """Exporta proyección de muros caja a DXF (capa WALLS, metros en modelo)."""
    args = ExportDxfWallsParams.model_validate(params)
    path = Path(args.out_path).expanduser()
    if path.suffix.lower() != ".dxf":
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "out_path debe terminar en .dxf",
        )
    path = path.resolve()
    specs = topo_registry.all_wall_specs()
    if not specs:
        raise RpcError(
            ErrorCode.INVALID_PARAMS,
            "No hay muros en la sesión para exportar.",
        )
    view_range = _normalized_view_range(args.view, args.view_range)
    lines_world = _build_lines_world(args.view, specs, view_range)
    write_wall_projection_dxf(path, args.view, lines_world)
    return {
        "path": str(path),
        "segment_count": len(lines_world),
        "view": args.view,
    }


def register(dispatcher: Dispatcher) -> None:
    """Registra métodos ``draw.*``."""
    dispatcher.register("draw.ortho_snapshot", ortho_snapshot)
    dispatcher.register("draw.export_dxf_walls", export_dxf_walls)
