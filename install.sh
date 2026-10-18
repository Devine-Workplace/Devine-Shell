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
VENV_DIR="$DATA_HOME/devine/venv"

say() { printf '\nDevine: %s\n' "$*"; }
fail() { printf 'Devine: %s\n' "$*" >&2; exit 1; }

install_arch_aur_fallback() {
  local build_dir
  command -v makepkg >/dev/null 2>&1 || fail "Cava's development library is missing. Install paru or makepkg, then rerun ./install.sh."
  build_dir="$(mktemp -d "${TMPDIR:-/tmp}/devine-libcava.XXXXXX")"
  say "paru is unavailable; building the required libcava-git package with makepkg."
  git clone --depth 1 https://aur.archlinux.org/libcava-git.git "$build_dir/libcava-git"
  (cd "$build_dir/libcava-git" && makepkg --syncdeps --install --noconfirm)
  rm -rf "$build_dir"
}

install_system_dependencies() {
  local id="" like="" packages=() pm=""
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    id="${ID:-}"
    like="${ID_LIKE:-}"
  fi

  case " $id $like " in
    *" arch "*|*" cachyos "*|*" endeavouros "*|*" manjaro "*)
      command -v pacman >/dev/null || fail "This looks like an Arch-based system, but pacman is missing."
      packages=(quickshell cmake ninja gcc pkgconf git qt6-base qt6-declarative qt6-shadertools qt6-wayland libqalculate pipewire aubio cava lm_sensors python python-pip python-pillow)
      if command -v paru >/dev/null 2>&1; then
        packages+=(python-materialyoucolor libcava-git)
        pm=paru
      else
        pm=pacman
      fi
      ;;
    *" fedora "*|*" rhel "*|*" rocky "*|*" almalinux "*)
      command -v dnf >/dev/null || fail "This looks like a Fedora-based system, but dnf is missing."
      packages=(quickshell cmake ninja-build gcc-c++ pkgconf-pkg-config qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtshadertools-devel qt6-qtwayland-devel libqalculate-devel pipewire-devel aubio-devel cava-devel lm_sensors-devel python3 python3-pip)
      pm=dnf
      ;;
    *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*)
      command -v apt-get >/dev/null || fail "This looks like a Debian-based system, but apt-get is missing."
      packages=(quickshell cmake ninja-build g++ pkg-config qt6-base-dev qt6-declarative-dev qt6-shadertools-dev qt6-wayland-dev libqalculate-dev libpipewire-0.3-dev libaubio-dev libcava-dev libsensors-dev python3 python3-venv python3-pip)
      pm=apt
      ;;
    *)
      fail "Automatic dependency installation is not set up for '${id:-this Linux distro}'. Supported package managers are pacman (Arch/CachyOS), dnf (Fedora), and apt (Debian/Ubuntu). Install Quickshell, Qt 6.9+ development files, CMake, Ninja, a C++20 compiler, pkg-config, the Qalculate/PipeWire/Aubio/Cava/sensors development libraries, and Python 3.13+ with venv, then rerun ./install.sh."
      ;;
  esac

  case "$pm" in
    paru)
      say "CachyOS/Arch needs a full package sync before installing dependencies. This can update existing system packages too."
      read -r -p "Run paru -Syu --needed for Devine? [y/N] " answer
      [[ "$answer" =~ ^[Yy]$ ]] || fail "Cancelled before installing system packages."
      paru -Syu --needed "${packages[@]}"
      ;;
    pacman)
      say "CachyOS/Arch needs a full package sync before installing dependencies. This can update existing system packages too."
      read -r -p "Run sudo pacman -Syu --needed for Devine? [y/N] " answer
      [[ "$answer" =~ ^[Yy]$ ]] || fail "Cancelled before installing system packages."
      sudo pacman -Syu --needed "${packages[@]}"
      ;;
    dnf)
      sudo dnf install -y "${packages[@]}"
      ;;
    apt)
      sudo apt-get update
      sudo apt-get install -y "${packages[@]}"
      ;;
  esac

  if [[ "$pm" == pacman ]] && ! pkg-config --exists libcava; then
    install_arch_aur_fallback
  fi
}

python_bin=""
for candidate in python3.14 python3.13 python3; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(sys.version_info < (3, 13))'; then
    python_bin="$(command -v "$candidate")"
    break
  fi
done

missing=0
for cmd in qs git cmake ninja c++ pkg-config; do
  command -v "$cmd" >/dev/null 2>&1 || missing=1
done
pkg-config --exists Qt6Core libqalculate libpipewire-0.3 aubio || missing=1
pkg-config --exists Qt6ShaderTools Qt6Qml Qt6Gui Qt6Quick Qt6QuickControls2 Qt6Concurrent Qt6Sql Qt6Network Qt6DBus || missing=1
if ! pkg-config --exists libcava && ! pkg-config --exists cava; then
  missing=1
fi
[[ -f /usr/include/sensors/sensors.h ]] || missing=1
[[ -n "$python_bin" ]] || missing=1
if (( missing )); then
  install_system_dependencies
fi

for cmd in qs git cmake ninja c++ pkg-config; do
  command -v "$cmd" >/dev/null 2>&1 || fail "Required command '$cmd' is still missing after dependency installation. Check the package-manager error above."
done
python_bin=""
for candidate in python3.14 python3.13 python3; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; raise SystemExit(sys.version_info < (3, 13))'; then
    python_bin="$(command -v "$candidate")"
    break
  fi
done
[[ -n "$python_bin" ]] || fail "Devine's CLI needs Python 3.13 or newer. Install it and rerun ./install.sh."

mkdir -p "$DATA_HOME/devine"
if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  "$python_bin" -m venv "$VENV_DIR" || fail "Could not create the Python environment. Ensure your distro's Python venv package is installed."
fi
"$VENV_DIR/bin/python" -m pip install --disable-pip-version-check --upgrade pillow materialyoucolor

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
