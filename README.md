# Devine

Devine is a customized fork of [Caelestia Shell](https://github.com/caelestia-dots/shell) and its [CLI](https://github.com/caelestia-dots/cli), for Hyprland and Quickshell. Devine changes began on 2026-10-18. The adapted code is GPL-3.0-only. See [NOTICE.md](NOTICE.md) for credits and license details.

It includes a panel, app launcher, notifications, quick settings, and workspace tools.

## Install

Clone Devine and run its installer from a Hyprland session:

```sh
git clone https://github.com/Devine-Workplace/Devine-Shell.git && cd Devine-Shell && ./install.sh
```

The installer detects Arch/CachyOS, Fedora, or Debian/Ubuntu, installs the matching system packages, creates a private Python environment, builds Devine's native modules and its pinned M3Shapes dependency, and links the shell into your user config. On Arch-based systems it uses `paru` for AUR dependencies when available, otherwise `pacman`, and asks before running the full system sync. Start Devine with:

```sh
~/.local/bin/start-devine
```

Update later with `~/.local/bin/devine-update`.
