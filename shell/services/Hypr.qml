pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Devine.I18n
import Devine.Services
import qs.components.misc

Singleton {
    id: root

    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors
    readonly property bool usingLua: Hyprland.usingLua

    readonly property HyprlandToplevel activeToplevel: {
        const t = Hyprland.activeToplevel;
        const workspace = Hyprland.focusedWorkspace;
        // Workspace membership can arrive after the active window on reload.
        // Do not reject a valid active window just because its list is not ready.
        if (t && (t.workspace?.name.startsWith("special:") || !workspace || t.workspace?.id === workspace.id))
            return t;
        return Hyprland.toplevels.values.find(window => Number(window.workspace?.id) === Number(workspace?.id) && window.lastIpcObject?.mapped && Number(window.lastIpcObject?.focusHistoryID) === 0) ?? null;
    }
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int activeWsId: focusedWorkspace?.id ?? 1

    readonly property HyprKeyboard keyboard: extras.devices.keyboards.find(kb => kb.main) ?? null
    property bool shiftLockEnabled: false
    property int capsLockKeyEvents: 0
    readonly property bool capsLock: (keyboard?.capsLock ?? false) || shiftLockEnabled
    readonly property bool numLock: keyboard?.numLock ?? false
    readonly property string defaultKbLayout: keyboard?.layout.split(",")[0] ?? "??"
    readonly property string kbLayoutFull: keyboard?.activeKeymap ?? Tr.trCtx("Unknown", "keyboard layout")
    readonly property string kbLayout: kbMap.get(kbLayoutFull) ?? "??"
    readonly property var kbMap: new Map()

    readonly property alias extras: extras
    readonly property alias options: extras.options
    readonly property alias devices: extras.devices

    property string lastSpecialWorkspace: ""

    signal configReloaded

    function dispatch(request: string): void {
        Hyprland.dispatch(request);
    }

    function syncWindowBorderColour(): void {
        const colour = Colours.current.m3primary.toString().replace(/^#/, "").slice(0, 6);
        if (usingLua)
            extras.batchMessage([`eval hl.config({general={col={active_border="rgba(${colour}ff)"}}})`]);
        else
            extras.batchMessage([`keyword general:col.active_border rgb(${colour})`]);
    }

    function focusWorkspace(ws: var): void {
        const workspace = workspaces.values.find(w => w.id === Number(ws) || w.name === String(ws));
        const selector = workspace && workspace.id < 0 ? (workspace.name.startsWith("special:") ? workspace.name : "name:" + workspace.name) : String(ws);
        dispatch(usingLua ? `hl.dsp.focus({ workspace = ${JSON.stringify(selector)} })` : `workspace ${selector}`);
    }

    function toggleSpecial(name: string): void {
        dispatch(usingLua ? `hl.dsp.workspace.toggle_special("${name}")` : `togglespecialworkspace ${name}`);
    }

    function cycleSpecialWorkspace(direction: string): void {
        const openSpecials = workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0);

        if (openSpecials.length === 0)
            return;

        const activeSpecial = focusedMonitor.lastIpcObject.specialWorkspace.name ?? "";

        if (!activeSpecial) {
            if (lastSpecialWorkspace) {
                const workspace = workspaces.values.find(w => w.name === lastSpecialWorkspace);
                if (workspace && workspace.lastIpcObject.windows > 0) {
                    focusWorkspace(lastSpecialWorkspace);
                    return;
                }
            }
            focusWorkspace(openSpecials[0].name);
            return;
        }

        const currentIndex = openSpecials.findIndex(w => w.name === activeSpecial);
        let nextIndex = 0;

        if (currentIndex !== -1) {
            if (direction === "next")
                nextIndex = (currentIndex + 1) % openSpecials.length;
            else
                nextIndex = (currentIndex - 1 + openSpecials.length) % openSpecials.length;
        }

        focusWorkspace(openSpecials[nextIndex].name);
    }

    function monitorNames(): list<string> {
        return monitors.values.map(e => e.name);
    }

    function monitorFor(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitorFor(screen);
    }

    function trimWsName(name: string): string {
        return name.startsWith("special:") ? name.slice("special:".length) : name;
    }

    function toplevelsForWs(ws: int, ignoredTags = []): list<HyprlandToplevel> {
        return toplevels.values.filter(t => t.workspace && t.workspace.id === ws && !isToplevelIgnored(t, ignoredTags));
    }

    function isToplevelIgnored(toplevel: HyprlandToplevel, ignoredTags = []): bool {
        const ipc = toplevel?.lastIpcObject;
        if (!ipc?.class || !ipc.mapped)
            return true;

        return ipc.tags?.some(tag => ignoredTags.includes(tag.replace(/\*$/, ""))) ?? false;
    }

    function reloadDynamicConfs(): void {
        const keyBindings = [Keybinds.switcher, Keybinds.switcherBack, Keybinds.overview, Keybinds.launcher, Keybinds.settings, Keybinds.screenshot, Keybinds.clipboard, Keybinds.explorer];
        const legacyBindings = keyBindings.map(toHyprBinding);
        const oldKeyBindings = root.lastDevineBindings;
        if (usingLua) {
            extras.batchMessage([...[...new Set([...oldKeyBindings, ...keyBindings, "ALT + Tab", "ALT + SHIFT + Tab", "SUPER + Tab", "SUPER + Space", "SUPER + Z", "SUPER + SHIFT + S", "SUPER + V", "SUPER + E", "Caps_Lock", "Num_Lock", "Shift_Lock", "code:66"])].map(k => `eval hl.unbind("${k}")`), 'eval hl.bind("Num_Lock", hl.dsp.global("devine:refreshDevices"), { locked = true, non_consuming = true, ignore_mods = true, release = true })', 'eval hl.bind("code:66", hl.dsp.global("devine:capsLockKey"), { locked = true, non_consuming = true, ignore_mods = true })', `eval hl.bind("${Keybinds.switcher}", hl.dsp.global("devine:switcherNext"))`, `eval hl.bind("${Keybinds.switcherBack}", hl.dsp.global("devine:switcherPrevious"))`, `eval hl.bind("${Keybinds.overview}", hl.dsp.global("devine:switcherOverview"))`, `eval hl.bind("${Keybinds.launcher}", hl.dsp.global("devine:launcher"))`, `eval hl.bind("${Keybinds.settings}", hl.dsp.global("devine:nexus"))`, `eval hl.bind("${Keybinds.screenshot}", hl.dsp.global("devine:screenshot"))`, `eval hl.bind("${Keybinds.clipboard}", hl.dsp.global("devine:clipboard"))`, `eval hl.bind("${Keybinds.explorer}", hl.dsp.global("devine:explorer"))`]);
        } else {
            extras.batchMessage([...[...new Set([...oldKeyBindings.map(toHyprBinding), ...legacyBindings, "ALT,Tab", "ALT SHIFT,Tab", "SUPER,Tab", "SUPER,Space", "SUPER,Z", "SUPER SHIFT,S", "SUPER,V", "SUPER,E", ",Caps_Lock", ",Num_Lock", ",Shift_Lock", ",code:66"])].map(k => `keyword unbind ${k}`), "keyword bindlni ,Num_Lock,global,devine:refreshDevices", "keyword bindlni ,code:66,global,devine:capsLockKey", `keyword bind ${legacyBindings[0]},global,devine:switcherNext`, `keyword bind ${legacyBindings[1]},global,devine:switcherPrevious`, `keyword bind ${legacyBindings[2]},global,devine:switcherOverview`, `keyword bind ${legacyBindings[3]},global,devine:launcher`, `keyword bind ${legacyBindings[4]},global,devine:nexus`, `keyword bind ${legacyBindings[5]},global,devine:screenshot`, `keyword bind ${legacyBindings[6]},global,devine:clipboard`, `keyword bind ${legacyBindings[7]},global,devine:explorer`]);
        }
        root.lastDevineBindings = keyBindings;
    }

    function toHyprBinding(binding: string): string {
        const parts = binding.split("+").map(p => p.trim());
        const key = parts.pop() ?? "";
        return `${parts.join(" ")},${key}`;
    }

    property var lastDevineBindings: ["ALT + Tab", "ALT + SHIFT + Tab", "SUPER + Tab", "SUPER + Space", "SUPER + Z", "SUPER + SHIFT + S", "SUPER + V", "SUPER + E"]

    onUsingLuaChanged: {
        reloadDynamicConfs();
        syncWindowBorderColour();
    }
    Connections {
        target: Colours.current
        function onM3primaryChanged(): void {
            Hypr.syncWindowBorderColour();
        }
    }
    Timer {
        id: borderColourReload
        interval: 100
        onTriggered: root.syncWindowBorderColour()
    }
    Connections {
        target: Keybinds
        function onLoadingChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onSwitcherChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onSwitcherBackChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onOverviewChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onLauncherChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onSettingsChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onScreenshotChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onExplorerChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
        function onClipboardChanged(): void {
            if (!Keybinds.loading)
                Hypr.reloadDynamicConfs();
        }
    }
    Component.onCompleted: {
        reloadDynamicConfs();
        syncWindowBorderColour();
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Connections {
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;

            if (n === "configreloaded") {
                root.configReloaded();
                root.reloadDynamicConfs();
                borderColourReload.restart();
            } else if (["workspace", "moveworkspace", "activespecial", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            } else if (["openwindow", "closewindow", "movewindow"].includes(n)) {
                Hyprland.refreshToplevels();
                Hyprland.refreshWorkspaces();
            } else if (n.includes("mon")) {
                Hyprland.refreshMonitors();
            } else if (n.includes("workspace")) {
                Hyprland.refreshWorkspaces();
            } else if (n.includes("window") || n.includes("group") || ["pin", "fullscreen", "changefloatingmode", "minimize"].includes(n)) {
                Hyprland.refreshToplevels();
            }
        }

        target: Hyprland
    }

    Connections {
        function onLastIpcObjectChanged(): void {
            const specialName = root.focusedMonitor.lastIpcObject.specialWorkspace.name;

            if (specialName && specialName.startsWith("special:")) {
                root.lastSpecialWorkspace = specialName;
            }
        }

        target: root.focusedMonitor
    }

    FileView {
        id: kbLayoutFile

        path: Quickshell.env("DEVINE_XKB_RULES_PATH") || "/usr/share/X11/xkb/rules/base.lst"
        onLoaded: {
            const layoutMatch = text().match(/! layout\n([\s\S]*?)\n\n/);
            if (layoutMatch) {
                const lines = layoutMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-z]{2,})\s+([a-zA-Z() ]+)$/);
                    if (match)
                        root.kbMap.set(match[2], match[1]);
                }
            }

            const variantMatch = text().match(/! variant\n([\s\S]*?)\n\n/);
            if (variantMatch) {
                const lines = variantMatch[1].split("\n");
                for (const line of lines) {
                    if (!line.trim() || line.trim().startsWith("!"))
                        continue;

                    const match = line.match(/^\s*([a-zA-Z0-9_-]+)\s+([a-z]{2,}): (.+)$/);
                    if (match)
                        root.kbMap.set(match[3], match[2]);
                }
            }
        }
    }

    IpcHandler {
        function refreshDevices(): void {
            extras.refreshDevices();
        }

        function cycleSpecialWorkspace(direction: string): void {
            root.cycleSpecialWorkspace(direction);
        }

        function listSpecialWorkspaces(): string {
            return root.workspaces.values.filter(w => w.name.startsWith("special:") && w.lastIpcObject.windows > 0).map(w => w.name).join("\n");
        }

        target: "hypr"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "refreshDevices"
        description: "Reload devices"
        onPressed: extras.refreshDevices()
        onReleased: extras.refreshDevices()
    }

    CustomShortcut {
        name: "capsLockKey"
        description: "Update Caps Lock indicator"
        onPressed: {
            root.capsLockKeyEvents++;
            if (root.keyboard?.lastIpcObject?.options?.includes("caps:shiftlock")) {
                root.shiftLockEnabled = !root.shiftLockEnabled;
                shiftLockState.setText(JSON.stringify({
                    enabled: root.shiftLockEnabled
                }));
            }
            lockRefresh.restart();
        }
    }

    Timer {
        id: lockRefresh
        interval: 40
        onTriggered: extras.refreshDevices()
    }

    FileView {
        id: shiftLockState
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/devine-shift-lock.json"
        onLoaded: {
            try {
                root.shiftLockEnabled = JSON.parse(text()).enabled === true;
            } catch (e) {}
        }
    }

    HyprExtras {
        id: extras

        usingLua: Hyprland.usingLua
    }
}
