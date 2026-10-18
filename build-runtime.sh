#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BUILD_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/devine/build"
cmake -S "$ROOT_DIR/runtime" -B "$BUILD_HOME" -G Ninja \
  -DVERSION=0.1.0 \
  -DGIT_REVISION="$(git -C "$ROOT_DIR" rev-parse --short HEAD 2>/dev/null || echo source)" \
  -DDISTRIBUTOR=Devine \
  -DENABLE_MODULES="extras;plugin" \
  -DINSTALL_LIBDIR=lib/devine \
  -DINSTALL_QMLDIR=lib/qt6/qml \
  -DCMAKE_INSTALL_PREFIX="$HOME/.local"
cmake --build "$BUILD_HOME" --parallel "$(nproc)"
cmake --install "$BUILD_HOME"
