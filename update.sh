#!/usr/bin/env bash
set -euo pipefail
SOURCE="$(readlink -f -- "${BASH_SOURCE[0]}")"
ROOT_DIR="$(cd -- "$(dirname -- "$SOURCE")" && pwd -P)"
if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This Devine copy is not a Git checkout; clone it from GitHub before updating." >&2
  exit 1
fi
git -C "$ROOT_DIR" pull --ff-only origin main
"$ROOT_DIR/install.sh"
