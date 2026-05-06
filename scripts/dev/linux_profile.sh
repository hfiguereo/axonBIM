#!/usr/bin/env bash
# (c) 2026 Arq. Hector Nathanael Figuereo. GPLv3.
#
# Perfil Linux/Fedora para ejecución más consistente.
# Se carga desde scripts/dev/run_dev.sh en hosts Linux.

# Evita que Mesa/Godot intenten primero la dGPU en portátiles híbridos.
if [[ -z "${DRI_PRIME:-}" ]]; then
	export DRI_PRIME=0
fi

# Fedora/Wayland puede introducir jitter en coordenadas del mouse para algunos
# subviewports; se permite forzar X11 con una variable explícita.
if [[ "${AXONBIM_FORCE_X11:-0}" == "1" ]]; then
	export GDK_BACKEND=x11
	export QT_QPA_PLATFORM=xcb
fi
