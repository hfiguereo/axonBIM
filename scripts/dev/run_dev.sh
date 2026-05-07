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
#   AXONBIM_GODOT_REQUIRED_VERSION  Version minima de Godot (default 4.6.2)
#   AXONBIM_GODOT_AUTO_UPDATE       En Linux: 1 auto-instala/actualiza oficial, 0 desactiva (default 1)
#   AXONBIM_FORCE_X11               En Linux: 1 para forzar X11 (default 0)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PORT="${AXONBIM_RPC_PORT:-5799}"
export AXONBIM_RPC_PORT="${PORT}"
LOG_LEVEL="${AXONBIM_LOG_LEVEL:-INFO}"
REQUIRED_GODOT_VERSION="${AXONBIM_GODOT_REQUIRED_VERSION:-4.6.2}"
AUTO_UPDATE_GODOT="${AXONBIM_GODOT_AUTO_UPDATE:-1}"

_is_linux=0
if [[ "$(uname -s)" == "Linux" ]]; then
	_is_linux=1
fi

if [[ "${_is_linux}" -eq 1 && -f "${ROOT}/scripts/dev/linux_profile.sh" ]]; then
	# shellcheck source=/dev/null
	source "${ROOT}/scripts/dev/linux_profile.sh"
fi

_extract_version() {
	local raw="$1"
	if [[ "${raw}" =~ ([0-9]+\.[0-9]+(\.[0-9]+)?) ]]; then
		echo "${BASH_REMATCH[1]}"
		return 0
	fi
	return 1
}

_version_lt() {
	local a="$1"
	local b="$2"
	[[ "$(printf '%s\n%s\n' "${a}" "${b}" | sort -V | head -n1)" != "${b}" ]]
}

if [[ -n "${GODOT:-}" ]]; then
	GODOT_BIN="${GODOT}"
elif [[ -x "${HOME}/.local/bin/godot" ]]; then
	GODOT_BIN="${HOME}/.local/bin/godot"
else
	GODOT_BIN="$(command -v godot || true)"
fi
if [[ -z "${GODOT_BIN}" ]]; then
	if [[ "${_is_linux}" -eq 1 && "${AUTO_UPDATE_GODOT}" == "1" ]]; then
		echo "AxonBIM: Godot no encontrado, instalando ${REQUIRED_GODOT_VERSION} oficial..."
		GODOT_VERSION="${REQUIRED_GODOT_VERSION}" bash "${ROOT}/scripts/dev/install_godot_official.sh"
		GODOT_BIN="${HOME}/.local/bin/godot"
	else
		echo "Godot no encontrado. Instala el binario oficial (p. ej. scripts/dev/install_godot_official.sh) o export GODOT=/ruta/al/godot" >&2
		exit 1
	fi
fi

if [[ "${_is_linux}" -eq 1 ]]; then
	_godot_raw_version="$("${GODOT_BIN}" --version 2>/dev/null || true)"
	_godot_version="$(_extract_version "${_godot_raw_version}" || true)"
	if [[ -n "${_godot_version}" ]] && _version_lt "${_godot_version}" "${REQUIRED_GODOT_VERSION}"; then
		if [[ "${AUTO_UPDATE_GODOT}" == "1" ]]; then
			echo "AxonBIM: Godot ${_godot_version} < ${REQUIRED_GODOT_VERSION}, actualizando..."
			GODOT_VERSION="${REQUIRED_GODOT_VERSION}" bash "${ROOT}/scripts/dev/install_godot_official.sh"
			GODOT_BIN="${HOME}/.local/bin/godot"
		else
			echo "AxonBIM: aviso: Godot ${_godot_version} < ${REQUIRED_GODOT_VERSION} (auto-update desactivado)." >&2
		fi
	fi
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
