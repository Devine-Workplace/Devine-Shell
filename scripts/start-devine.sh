#!/usr/bin/env bash
set -euo pipefail
SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SOURCE")" && pwd -P)"
export QML2_IMPORT_PATH="$HOME/.local/lib/qt6/qml${QML2_IMPORT_PATH:+:$QML2_IMPORT_PATH}"
export DEVINE_LIB_DIR="$HOME/.local/lib/devine"
QSG_RENDER_LOOP=threaded QSG_USE_SIMPLE_ANIMATION_DRIVER=1 "$SCRIPT_DIR/devine" shell -d
for unit in devine-polkit devine-clipboard-text devine-clipboard-image; do
  if ! systemctl --user is-active --quiet "$unit.service"; then
    case "$unit" in
      devine-polkit) command -v hyprpolkitagent >/dev/null && systemd-run --user --collect --unit="$unit" hyprpolkitagent ;;
      devine-clipboard-text) command -v wl-paste >/dev/null && command -v cliphist >/dev/null && systemd-run --user --collect --unit="$unit" wl-paste --type text --watch cliphist store ;;
      devine-clipboard-image) command -v wl-paste >/dev/null && command -v cliphist >/dev/null && systemd-run --user --collect --unit="$unit" wl-paste --type image --watch cliphist store ;;
    esac
  fi
done
