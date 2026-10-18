#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
BIN_DIR="$HOME/.local/bin"
CONFIG_TARGET="$CONFIG_HOME/quickshell/devine"
SCRIPT_TARGET="$DATA_HOME/devine/scripts"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$STATE_HOME/devine/backups/$STAMP"

for cmd in qs git cmake ninja c++ pkg-config python3; do
  command -v "$cmd" >/dev/null || { echo "Missing build or runtime tool: $cmd" >&2; exit 1; }
done

python3 -c 'import PIL, materialyoucolor' 2>/dev/null || { echo "Devine needs Python packages pillow and materialyoucolor." >&2; exit 1; }

"$ROOT_DIR/build-runtime.sh"
mkdir -p "$(dirname "$CONFIG_TARGET")" "$DATA_HOME/devine" "$BIN_DIR" "$STATE_HOME/devine/backups"
if [[ -e "$CONFIG_TARGET" || -L "$CONFIG_TARGET" ]]; then
  if [[ "$(readlink -f "$CONFIG_TARGET" 2>/dev/null || true)" != "$(readlink -f "$ROOT_DIR/shell")" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$CONFIG_TARGET" "$BACKUP_DIR/quickshell-devine"
  fi
fi
if [[ ! -e "$CONFIG_TARGET" ]]; then ln -s "$ROOT_DIR/shell" "$CONFIG_TARGET"; fi
if [[ -e "$SCRIPT_TARGET" || -L "$SCRIPT_TARGET" ]]; then
  if [[ "$(readlink -f "$SCRIPT_TARGET" 2>/dev/null || true)" != "$(readlink -f "$ROOT_DIR/scripts")" ]]; then
    mkdir -p "$BACKUP_DIR"
    mv "$SCRIPT_TARGET" "$BACKUP_DIR/devine-scripts"
  fi
fi
if [[ ! -e "$SCRIPT_TARGET" ]]; then ln -s "$ROOT_DIR/scripts" "$SCRIPT_TARGET"; fi
ln -sfn "$ROOT_DIR/scripts/devine" "$BIN_DIR/devine"
ln -sfn "$ROOT_DIR/scripts/start-devine.sh" "$BIN_DIR/start-devine"
ln -sfn "$ROOT_DIR/update.sh" "$BIN_DIR/devine-update"
printf 'Devine installed. Launch with %s/start-devine\n' "$BIN_DIR"
