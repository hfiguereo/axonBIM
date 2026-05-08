#!/usr/bin/env bash
# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
#
# Humo mínimo: Godot abre el proyecto y sale sin error (headless).
# Requiere `godot` en PATH o AXONBIM_GODOT_BIN apuntando al binario.
#
# Uso: bash scripts/dev/smoke_godot.sh
#      AXONBIM_GODOT_BIN="$HOME/.local/bin/godot" bash scripts/dev/smoke_godot.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT_BIN="${AXONBIM_GODOT_BIN:-}"
if [[ -z "${GODOT_BIN}" ]]; then
	if [[ -x "${HOME}/.local/bin/godot" ]]; then
		GODOT_BIN="${HOME}/.local/bin/godot"
	else
		GODOT_BIN="$(command -v godot || true)"
	fi
fi
if [[ -z "${GODOT_BIN}" ]]; then
	echo "smoke_godot: no hay binario Godot (PATH o AXONBIM_GODOT_BIN o ~/.local/bin/godot)." >&2
	exit 1
fi

echo "smoke_godot: usando ${GODOT_BIN}"
exec "${GODOT_BIN}" --headless --path "${ROOT}/frontend" --quit
