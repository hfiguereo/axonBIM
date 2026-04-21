#!/usr/bin/env bash
# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
#
# Lanza el backend AxonBIM y abre Godot conectado al mismo puerto TCP.
# Uso: ./scripts/dev/run_dev.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

PORT="${AXONBIM_RPC_PORT:-$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')}"
LOG_LEVEL="${AXONBIM_LOG_LEVEL:-INFO}"

echo "Backend RPC TCP -> 127.0.0.1:${PORT}"

uv run python -m axonbim --tcp-port "${PORT}" --log-level "${LOG_LEVEL}" &
BACKEND_PID=$!
trap 'kill "$BACKEND_PID" 2>/dev/null || true' EXIT

sleep 0.5

AXONBIM_RPC_PORT="${PORT}" \
  godot --path frontend --rendering-driver vulkan -- --rpc-port="${PORT}"
