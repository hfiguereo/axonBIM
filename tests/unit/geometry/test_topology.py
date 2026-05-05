# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
"""Tests de IDs topológicos persistentes."""

from __future__ import annotations

import pytest

from axonbim.geometry.topology import compute_topo_id


def test_returns_16_char_hex() -> None:
    topo = compute_topo_id((1.0, 2.0, 3.0), 4.0, (0.0, 0.0, 1.0))
    assert len(topo) == 16
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


def test_persistent_mode_returns_16_hex() -> None:
    topo = compute_topo_id(
        (1.0, 2.0, 3.0),
        4.0,
        (0.0, 0.0, 1.0),
        entity_type="FACE",
        parent_guid="wall-001",
        op_signature="wall_box:v1:face:top",
    )
    assert len(topo) == 16
    int(topo, 16)


def test_persistent_mode_includes_parent_guid() -> None:
    a = compute_topo_id(
        (1.0, 2.0, 3.0),
        4.0,
        (0.0, 0.0, 1.0),
        entity_type="FACE",
        parent_guid="wall-a",
        op_signature="wall_box:v1:face:top",
    )
    b = compute_topo_id(
        (1.0, 2.0, 3.0),
        4.0,
        (0.0, 0.0, 1.0),
        entity_type="FACE",
        parent_guid="wall-b",
        op_signature="wall_box:v1:face:top",
    )
    assert a != b


def test_persistent_mode_requires_context_pair() -> None:
    with pytest.raises(ValueError, match="persistent topology"):
        compute_topo_id(
            (1.0, 2.0, 3.0),
            4.0,
            (0.0, 0.0, 1.0),
            entity_type="FACE",
            parent_guid="wall-a",
        )
