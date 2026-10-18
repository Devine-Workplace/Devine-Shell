# Devine

Devine is a desktop shell for Hyprland, built with Quickshell. It includes a panel, app launcher, notifications, quick settings, and workspace tools.

Devine builds and runs its own shell modules and command line tools. It does not need the Caelestia package installed. Some source is adapted from Caelestia; see [NOTICE.md](NOTICE.md) and the included licenses.

## Install

In a Hyprland session, install Quickshell (`qs`), CMake, Ninja, a C++20 compiler, `pkg-config`, Python 3, Pillow, and `materialyoucolor`. Then run:

```sh
git clone https://github.com/Devine-Workplace/Devine-Shell.git
cd Devine-Shell
./install.sh
~/.local/bin/start-devine
```

Update later with `~/.local/bin/devine-update`.
