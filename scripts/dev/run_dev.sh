#!/usr/bin/env bash
# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
#
# Arranque unificado: levanta el backend RPC (TCP) y abre Godot en un solo comando.
# Al cerrar Godot, el backend se detiene.
#
# Uso (preferido: un solo comando desde la raíz del repo):
#   ./start
#   make start
#   bash scripts/dev/run_dev.sh
#
# Variables opcionales:
#   AXONBIM_RPC_PORT   Puerto TCP (default 5799)
#   AXONBIM_LOG_LEVEL  INFO, DEBUG, ...
#   GODOT              Ruta al binario Godot (default: ~/.local/bin/godot si existe, si no `godot` en PATH)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PORT="${AXONBIM_RPC_PORT:-5799}"
export AXONBIM_RPC_PORT="${PORT}"
LOG_LEVEL="${AXONBIM_LOG_LEVEL:-INFO}"

if [[ -n "${GODOT:-}" ]]; then
	GODOT_BIN="${GODOT}"
elif [[ -x "${HOME}/.local/bin/godot" ]]; then
	GODOT_BIN="${HOME}/.local/bin/godot"
else
	GODOT_BIN="$(command -v godot || true)"
fi
if [[ -z "${GODOT_BIN}" ]]; then
	echo "Godot no encontrado. Instala el binario oficial (p. ej. scripts/dev/install_godot_official.sh) o export GODOT=/ruta/al/godot" >&2
	exit 1
fi

# Portatil Intel + NVIDIA: sin DRI_PRIME, Mesa/Godot suelen intentar la dGPU y
# mostrar "failed to load driver: nvidia-drm" aunque luego rendericen con Intel.
if [[ -z "${DRI_PRIME:-}" ]]; then
	export DRI_PRIME=0
fi

_import_nonempty=0
if [[ -d "${ROOT}/frontend/.godot/imported" ]]; then
	for _f in "${ROOT}/frontend/.godot/imported/"*; do
		if [[ -e "${_f}" ]]; then
			_import_nonempty=1
			break
		fi
	done
fi
_port_busy=0
if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | grep -qE ":${PORT}\\s"; then
	_port_busy=1
fi

if [[ "${_port_busy}" -eq 1 ]]; then
	echo "AxonBIM: el puerto TCP ${PORT} ya esta en uso (otra instancia de ./start?). Cerrala o: AXONBIM_RPC_PORT=5800 ./start" >&2
	exit 1
fi

if [[ "${_import_nonempty}" -eq 0 ]]; then
	echo "AxonBIM: importando recursos Godot (primera ejecucion o sin .godot/imported)..." >&2
	"${GODOT_BIN}" --path "${ROOT}/frontend" --import
fi

echo "AxonBIM: backend TCP 127.0.0.1:${PORT} + Godot (frontend/)"

uv run python -m axonbim --tcp-port "${PORT}" --log-level "${LOG_LEVEL}" &
BACKEND_PID=$!

cleanup() {
	if [[ -n "${BACKEND_PID:-}" ]] && kill -0 "${BACKEND_PID}" 2>/dev/null; then
		kill "${BACKEND_PID}" 2>/dev/null || true
		wait "${BACKEND_PID}" 2>/dev/null || true
	fi
}
trap cleanup EXIT INT TERM

# Esperar a que el puerto este en LISTEN (sin abrir TCP al RPC: un probe con
# /dev/tcp o echo envia bytes y provoca FramingError "Mensaje sin Content-Length").
_ready=0
for _ in $(seq 1 50); do
	if command -v ss >/dev/null 2>&1; then
		if ss -ltn 2>/dev/null | grep -qE ":${PORT}\\s"; then
			_ready=1
			break
		fi
	else
		sleep 0.5
		_ready=1
		break
	fi
	sleep 0.1
done
if [[ "${_ready}" -eq 0 ]]; then
	echo "Advertencia: no se detecto el puerto ${PORT} en ss; esperando 0.3s..." >&2
	sleep 0.3
fi

# RpcClient lee AXONBIM_RPC_PORT y --rpc-port= en args de usuario (ver rpc_client.gd)
set +e
AXONBIM_RPC_PORT="${PORT}" "${GODOT_BIN}" --path "${ROOT}/frontend" -- --rpc-port="${PORT}"
GODOT_EXIT=$?
set -e
cleanup
trap - EXIT INT TERM
exit "${GODOT_EXIT}"
