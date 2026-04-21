# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests del stub de IDs topologicos."""

from __future__ import annotations

from axonbim.geometry.topology import compute_topo_id


def test_returns_40_char_hex() -> None:
    topo = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    assert len(topo) == 40
    int(topo, 16)


def test_deterministic_for_same_inputs() -> None:
    a = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    b = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    assert a == b


def test_different_when_centroid_changes() -> None:
    a = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    b = compute_topo_id((1.0, 2.0, 3.1), 4.0, (0.0, 0.0, 1.0))
    assert a != b


def test_different_when_area_changes() -> None:
    a = compute_topo_id((0.0, 0.0, 0.0), 1.0, (0.0, 0.0, 1.0))
    b = compute_topo_id((0.0, 0.0, 0.0), 2.0, (0.0, 0.0, 1.0))
    assert a != b


def test_normalizes_negative_zero() -> None:
    a = compute_topo_id((0.0, 0.0, 0.0), 1.0, (0.0, 0.0, 1.0))
    b = compute_topo_id((-0.0, 0.0, 0.0), 1.0, (0.0, 0.0, 1.0))
    assert a == b


def test_tolerates_subprecision_noise() -> None:
    a = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    b = compute_topo_id((1.0 + 1e-10, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    assert a == b
