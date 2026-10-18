# Devine Shell

A customized Hyprland desktop setup with a bottom panel, animated workspace overview, theme-matched popouts, and screenshot helpers.

Devine is a community customization based on Caelestia Shell and Quickshell. It keeps the compatible Caelestia runtime and module IDs for now, while the visible project identity and helper command are Devine. This is an installable customization, not an independently reimplemented shell engine. See [NOTICE.md](NOTICE.md) for credit and [LICENSE](LICENSE) for licensing.

## Install on CachyOS / Arch

Install the runtime and tools first. Devine currently expects the Caelestia shell runtime/CLI, Quickshell, Hyprland, Python, `grim`, `slurp`, `wl-clipboard`, and Swash. On CachyOS/Arch, install the runtime from your trusted package source (for example the `caelestia-shell` AUR package) before using this customization.

Clone this repository on the main PC or VM and install the Devine files:

```sh
git clone https://github.com/Devine-Workplace/Devine-Shell.git ~/.local/share/devine/source
cd ~/.local/share/devine/source
./install.sh
```

The installer backs up an existing Quickshell configuration before linking Devine. It does not install packages or change Hyprland keybinds. Launch with `~/.local/bin/start-devine`.

## Update

From the cloned repository, run `./update.sh`, or use the installed `~/.local/bin/devine-update` command. It fast-forwards from GitHub and re-runs the safe file-link installer.

On the main PC, keep `/mnt/Data/Projects/Devine-Shell` as the editable source of truth and push reviewed commits to `main`. The VM clones that same repository once and then runs `~/.local/bin/devine-update` to pull and install changes. No ISO or VM disk files belong in the repo.

## Current compatibility details

The upstream engine currently expects the Quickshell config ID `caelestia` and registers QML modules under the `Caelestia.*` namespace. Devine keeps those internal IDs so existing runtime IPC and modules continue to work. The launcher is named `devine`, and the About page displays Devine. Replacing the underlying runtime/CLI is a separate project.
