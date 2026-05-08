#!/usr/bin/env bash
# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
#
# Perfil Linux/Fedora para ejecución más consistente.
# Se carga desde scripts/dev/run_dev.sh en hosts Linux.
#
# GPU (ver ADR-0005 y README):
#   AXONBIM_GPU_PROFILE=auto|integrated|dedicated (default auto)
#     auto       — no exporta variables de selección de GPU.
#     integrated — no fuerza PRIME; deja al SO / variables del usuario.
#     dedicated  — exporta DRI_PRIME=1 para PRIME offload a dGPU (portátil híbrido).

GPU_PROFILE_RAW="${AXONBIM_GPU_PROFILE:-auto}"
GPU_PROFILE_LC="$(printf '%s' "${GPU_PROFILE_RAW}" | tr '[:upper:]' '[:lower:]')"

case "${GPU_PROFILE_LC}" in
	auto) ;;
	integrated) ;;
	dedicated)
		export DRI_PRIME=1
		;;
	*)
		echo "AxonBIM: AXONBIM_GPU_PROFILE='${GPU_PROFILE_RAW}' no reconocido (use auto, integrated o dedicated). Se ignora." >&2
		;;
esac

# Fedora/Wayland puede introducir jitter en coordenadas del mouse para algunos
# subviewports; se permite forzar X11 con una variable explícita.
if [[ "${AXONBIM_FORCE_X11:-0}" == "1" ]]; then
	export GDK_BACKEND=x11
	export QT_QPA_PLATFORM=xcb
fi
