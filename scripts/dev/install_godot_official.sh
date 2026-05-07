#!/usr/bin/env bash
# Instala el binario oficial de Godot (Linux x86_64) en ~/.local/bin/godot.
# Version objetivo por defecto: 4.6.2-stable.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.6.2}"
ZIP_NAME="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${ZIP_NAME}"
DEST="${HOME}/.local/bin/godot"

echo "==> Descargando Godot ${GODOT_VERSION}-stable desde GitHub releases..."
mkdir -p "${HOME}/.local/bin"
curl -fsSL -o "/tmp/${ZIP_NAME}" "${URL}"
unzip -p "/tmp/${ZIP_NAME}" > "${DEST}.tmp"
mv "${DEST}.tmp" "${DEST}"
chmod +x "${DEST}"
rm -f "/tmp/${ZIP_NAME}"

echo "==> Instalado en: ${DEST}"
"${DEST}" --version

echo ""
echo "Siguiente paso (opcional): desinstalar Godot Flatpak si ya no lo quieres:"
echo "  flatpak uninstall -y org.godotengine.Godot"
echo ""
echo "Asegurate de que ~/.local/bin este delante en PATH (antes que /usr/bin):"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
echo "O ejecuta el editor con ruta completa:"
echo "  ${DEST} --path \"\$(pwd)/frontend\""
