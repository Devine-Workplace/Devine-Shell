pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    property string switcher: "ALT + Tab"
    property string switcherBack: "ALT + SHIFT + Tab"
    property string overview: "SUPER + Tab"
    property string launcher: "SUPER + Space"
    property string settings: "SUPER + Z"
    property string screenshot: "SUPER + SHIFT + S"
    property string clipboard: "SUPER + V"
    property string explorer: "SUPER + E"
    property bool loading: true

    function save(): void {
        if (loading)
            return;
        keybindFile.setText(JSON.stringify({
            switcher,
            switcherBack,
            overview,
            launcher,
            settings,
            screenshot,
            clipboard,
            explorer
        }, null, 2));
    }

    function setDefaults(): void {
        switcher = "ALT + Tab";
        switcherBack = "ALT + SHIFT + Tab";
        overview = "SUPER + Tab";
        launcher = "SUPER + Space";
        settings = "SUPER + Z";
        screenshot = "SUPER + SHIFT + S";
        clipboard = "SUPER + V";
        explorer = "SUPER + E";
        save();
    }

    onSwitcherChanged: save()
    onSwitcherBackChanged: save()
    onOverviewChanged: save()
    onLauncherChanged: save()
    onSettingsChanged: save()
    onScreenshotChanged: save()
    onClipboardChanged: save()
    onExplorerChanged: save()

    FileView {
        id: keybindFile
        path: Paths.config + "/keybinds.json"
        onLoaded: {
            try {
                const saved = JSON.parse(text());
                root.loading = true;
                root.switcher = saved.switcher || root.switcher;
                root.switcherBack = saved.switcherBack || root.switcherBack;
                root.overview = saved.overview || root.overview;
                root.launcher = saved.launcher || root.launcher;
                root.settings = saved.settings || root.settings;
                root.screenshot = saved.screenshot || root.screenshot;
                root.clipboard = saved.clipboard || root.clipboard;
                root.explorer = saved.explorer || root.explorer;
            } catch (e) {}
            root.loading = false;
        }
        onLoadFailed: {
            root.loading = false;
        }
    }
}
