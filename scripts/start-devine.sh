#!/usr/bin/env bash
set -euo pipefail
SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$SOURCE")" && pwd -P)"
QSG_RENDER_LOOP=threaded QSG_USE_SIMPLE_ANIMATION_DRIVER=1 "$SCRIPT_DIR/devine" shell -d
for unit in caelestia-polkit caelestia-clipboard-text caelestia-clipboard-image; do
  if ! systemctl --user is-active --quiet "$unit.service"; then
    case "$unit" in
      caelestia-polkit) command -v hyprpolkitagent >/dev/null && systemd-run --user --collect --unit="$unit" hyprpolkitagent ;;
      caelestia-clipboard-text) command -v wl-paste >/dev/null && command -v cliphist >/dev/null && systemd-run --user --collect --unit="$unit" wl-paste --type text --watch cliphist store ;;
      caelestia-clipboard-image) command -v wl-paste >/dev/null && command -v cliphist >/dev/null && systemd-run --user --collect --unit="$unit" wl-paste --type image --watch cliphist store ;;
    esac
  fi
done
