pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.components.containers
import qs.services
import qs.utils

Scope {
    id: root
    property var pendingClose: null
    property var closeDestination: null
    property int closeWindowCount: 0
    function desktopSiblings(ws): var { return desktops.filter(d => d.monitor?.name === ws.monitor?.name); }
    function requestClose(ws): void {
        if (closeProcess.running || dragging || dropAnimating || moveProcess.running || dropGuard.running) return;
        const siblings = desktopSiblings(ws);
        if (siblings.length < 2) { moveError = "Keep one desktop on each monitor."; return; }
        const i = siblings.findIndex(d => d.id === ws.id);
        closeDestination = siblings[i > 0 ? i - 1 : i + 1];
        closeWindowCount = Hypr.toplevels.values.filter(w => w.lastIpcObject.workspace?.id === ws.id).length;
        pendingClose = ws;
        if (!closeWindowCount) closeDesktop(false);
    }
    function closeDesktop(confirmed): void {
        if (!pendingClose || closeProcess.running) return;
        closeProcess.command = [Paths.scripts + "/desktop-control.py", String(pendingClose.id)];
        if (confirmed) closeProcess.command = closeProcess.command.concat(["--confirmed"]);
        closeProcess.running = true;
    }
    Process {
        id: closeProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    if (response.confirmationRequired) { root.closeWindowCount = response.count; return; }
                    if (response.ok) {
                        root.pendingClose = null;
                        if (response.destination !== undefined) root.desktopId = response.destination;
                        root.moveError = "";
                    } else root.moveError = response.error ?? "Could not close this desktop.";
                } catch(e) { root.moveError = "Could not close this desktop."; }
            }
        }
        onExited: refreshTimer.restart()
    }
    property bool dragging: false
    property var dragWindow: null
    property var hoverDropTarget: null
    property real returnOffsetX: 0
    property real returnOffsetY: 0
    ParallelAnimation {
        id: returnMorph
        NumberAnimation { target: root; property: "returnOffsetX"; to: 0; duration: 170; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "returnOffsetY"; to: 0; duration: 170; easing.type: Easing.OutCubic }
    }
    property bool dropAnimating: false
    property var dropDesktop: null
    property point dropCenter
    property int dragPreviewDesktopId: 0
    property int dropLockedDesktopId: -2147483648
    property string moveError: ""
    readonly property var monitorGroups: Hypr.monitors.values
    readonly property int desktopHeaderHeight: monitorColumn.implicitHeight + 36
    function refreshOverview(): void {
        allWindows = Hypr.toplevels.values.filter(w => w.wayland && w.lastIpcObject?.mapped !== false);
        if (overview) {
            if (!desktops.some(ws => ws.id === desktopId)) desktopId = Hypr.focusedWorkspace?.id ?? desktops[0]?.id ?? 1;
            selectDesktop(desktopId);
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (!root.opened || !root.overview || root.dragging || root.dropAnimating || root.pendingClose) return;
            const name = event.name.replace(/v2$/, "");
            if (name.includes("workspace") || ["openwindow", "closewindow", "movewindow", "focusedmon", "activespecial"].includes(name)) liveRefresh.restart();
        }
    }
    Timer {
        id: liveRefresh
        interval: 100
        onTriggered: if (root.opened && root.overview && !root.dragging && !root.dropAnimating && !root.pendingClose) root.refreshOverview()
    }
    Connections {
        target: Hypr
        function onFocusedWorkspaceChanged() {
            if (root.opened && root.overview && !root.dragging && !root.dropAnimating && !root.pendingClose) {
                root.desktopId = Hypr.focusedWorkspace?.id ?? root.desktopId;
                liveRefresh.restart();
            }
        }
    }
    function moveWindow(window, desktop): void {
        if (!window || !desktop || moveProcess.running) return;
        if ((window.workspace?.id ?? window.lastIpcObject?.workspace?.id) === desktop.id) return;
        const address = window.lastIpcObject.address ?? window.address;
        const target = desktop.name.startsWith("special:") ? desktop.name : desktop.id < 0 ? "name:" + desktop.name : String(desktop.id);
        if (!address) return;
        moveError = "";
        dropLockedDesktopId = desktop.id;
        selectDesktop(dragPreviewDesktopId);
        moveProcess.command = ["python3", Paths.scripts + "/move-window.py", address, target];
        moveProcess.running = true;
    }
    function absorbWindow(desktop, target, scene): void {
        if (!dragWindow || (dragWindow.workspace?.id ?? dragWindow.lastIpcObject?.workspace?.id) === desktop.id) return;
        dropGuard.restart();
        root.moveWindow(root.dragWindow, desktop);
        hoverDropTarget = null;
    }
    Timer { id: dropGuard; interval: 600 }

    Process {
        id: moveProcess
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "ok") root.moveError = text.trim();
        }
        onExited: { refreshTimer.restart(); }
    }
    Timer { id: refreshTimer; interval: 150; onTriggered: root.refreshOverview() }
    property var allWindows: []
    property int desktopId: 0
    property var desktopNames: ({})
    readonly property var desktops: Hypr.workspaces.values.filter(w => !w.name.startsWith("special:") || allWindows.some(t => t.lastIpcObject.workspace?.id === w.id)).sort((a,b) => a.id-b.id)
    function desktopName(ws): string { return desktopNames[String(ws.id)] ?? (ws.id > 0 ? "Desktop " + ws.id : ws.name.replace("special:", "")); }
    function selectDesktop(id): void {
        desktopId = id;
        windows = allWindows.filter(w => w.lastIpcObject.workspace?.id === id);
        selected = 0;
    }
    property var pendingEnter: null
    property string pendingCreateMonitor: ""
    function enterDesktop(): void {
        pendingEnter = desktops.find(w => w.id === desktopId);
        cancel(); focusDelay.restart();
    }
    Timer {
        id: focusDelay
        interval: 240
        onTriggered: {
            const ws = root.pendingEnter;
            if (!ws) return;
            if (ws.name.startsWith("special:")) {
                if (Hypr.activeWsId !== ws.id) Hypr.toggleSpecial(ws.name.replace("special:", ""));
            } else Hypr.focusWorkspace(ws.id < 0 ? "name:" + ws.name : ws.id);
            root.pendingEnter = null;
        }
    }
    function createDesktop(monitor): void {
        if (createProcess.running || createDelay.running) return;
        pendingCreateMonitor = monitor;
        cancel(); createDelay.restart();
    }
    Timer {
        id: createDelay
        interval: 240
        onTriggered: {
            createProcess.command = [Paths.scripts + "/desktop-control.py", "create", root.pendingCreateMonitor];
            createProcess.running = true;
        }
    }
    Process {
        id: createProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    if (response.ok) root.desktopId = response.desktop;
                    else root.moveError = response.error ?? "Could not create this desktop.";
                } catch(e) { root.moveError = "Could not create this desktop."; }
            }
        }
        onExited: refreshTimer.restart()
    }
    function renameDesktop(id, name): void {
        const clean = name.trim();
        if (!clean) return;
        const names = Object.assign({}, desktopNames);
        names[String(id)] = clean;
        desktopNames = names;
        namesFile.setText(JSON.stringify(names));
    }
    FileView {
        id: namesFile
        path: Paths.config + "/workspace-names.json"
        onLoaded: { try { root.desktopNames = JSON.parse(text()); } catch(e) {} }
    }
    property bool overview: false
    readonly property int columns: overview ? Math.max(1, Math.min(4, windows.length, Math.floor(((targetScreen?.width ?? 1920) - 100) / 236))) : Math.max(1, windows.length)
    property bool opened: false
    property var windows: []
    property int selected: 0
    property var targetScreen: Quickshell.screens[0]

    function cycle(backwards: bool): void {
        if (!opened) {
            dropLockedDesktopId = -2147483648;
            overview = false;
            windows = Hypr.toplevels.values.filter(w => w.wayland && w.lastIpcObject?.mapped !== false)
                .sort((a,b) => (a.lastIpcObject.focusHistoryID ?? 999) - (b.lastIpcObject.focusHistoryID ?? 999));
            if (!windows.length) return;
            targetScreen = Quickshell.screens.find(s => s.name === Hypr.focusedMonitor?.name) ?? Quickshell.screens[0];
            selected = backwards ? windows.length - 1 : Math.min(1, windows.length - 1);
            opened = true;
        } else selected = (selected + (backwards ? -1 : 1) + windows.length) % windows.length;
    }
    function showOverview(): void {
        if (opened && overview) { cancel(); return; }
        if (!opened) cycle(false);
        allWindows = windows.slice();
        overview = true;
        selectDesktop(Hypr.activeToplevel?.workspace?.id ?? Hypr.focusedWorkspace?.id ?? 1);
    }
    function accept(): void {
        if (!opened) return;
        const chosen = windows[selected];
        opened = false;
        Qt.callLater(() => { if (chosen?.wayland) chosen.wayland.activate(); });
    }
    function cancel(): void { hoverDropTarget = null; returnMorph.stop(); dropAnimating = false; dropDesktop = null; pendingClose = null; dragging = false; dragWindow = null; opened = false; }
    IpcHandler {
        target: "switcher"
        function isOpen(): bool { return root.opened; }
        function shortcutsBlocked(): bool { return keyboardGuard.active; }
        function overview(): void { root.showOverview(); }
        function createDesktop(monitor: string): void { root.createDesktop(monitor); }
        function next(): void { root.cycle(false); }
        function previous(): void { root.cycle(true); }
        function accept(): void { root.accept(); }
        function cancel(): void { root.cancel(); }
    }
    Variants {
        model: Quickshell.screens
        StyledWindow {
            required property ShellScreen modelData
            name: "switcher-outside-dismiss"
            screen: modelData
            visible: root.opened && modelData.name !== root.targetScreen?.name
            anchors { top: true; bottom: true; left: true; right: true }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            MouseArea { anchors.fill: parent; onPressed: root.cancel() }
        }
    }
    StyledWindow {
        id: win
        name: "window-switcher"
        screen: root.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        visible: root.opened || panel.opacity > 0
        ShortcutInhibitor { id: keyboardGuard; window: win; enabled: root.opened }
        MouseArea { anchors.fill: parent; onClicked: root.cancel() }
        Item {
            id: keyReceiver
            anchors.fill: parent
            focus: root.opened
            Keys.onPressed: event => {
                if (root.pendingClose) {
                    if (event.key === Qt.Key_Escape) root.pendingClose = null;
                    else if (event.key === Qt.Key_Return) root.closeDesktop(true);
                    event.accepted = true; return;
                }
                if (root.overview && event.key === Qt.Key_Tab && (event.modifiers & Qt.MetaModifier)) root.cancel();
                else if (event.modifiers & Qt.ControlModifier) { event.accepted = true; return; }
                else if (event.key === Qt.Key_Escape) root.cancel();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.accept();
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab)
                    root.cycle(event.key === Qt.Key_Backtab || !!(event.modifiers & Qt.ShiftModifier));
                else if (event.key === Qt.Key_Right) root.cycle(false);
                else if (event.key === Qt.Key_Left) root.cycle(true);
                else { event.accepted = true; return; }
                event.accepted = true;
            }
            Keys.onReleased: event => {
                if (!root.overview && (event.key === Qt.Key_Alt || event.key === Qt.Key_AltGr)) {
                    root.accept(); event.accepted = true;
                }
            }
        }
        Rectangle {
            anchors.fill: parent
            color: Colours.palette.m3scrim
            opacity: panel.opacity * 0.22
        }
        Rectangle {
            z: 2000
            anchors.fill: parent
            visible: root.pendingClose !== null && root.closeWindowCount > 0
            color: Qt.alpha(Colours.palette.m3scrim, 0.4)
            MouseArea { anchors.fill: parent }
            Rectangle {
                anchors.centerIn: parent
                width: 430; height: 200; radius: 24
                color: Colours.palette.m3surfaceContainerHigh
                border.width: 1; border.color: Colours.palette.m3outlineVariant
                StyledText {
                    x: 24; y: 22; width: parent.width - 48
                    text: root.pendingClose ? "Close “" + root.desktopName(root.pendingClose) + "”?" : ""
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.body.medium
                }
                StyledText {
                    x: 24; y: 58; width: parent.width - 48
                    text: root.closeDestination ? root.closeWindowCount + " window(s) will move to “" + root.desktopName(root.closeDestination) + "”. Your apps will stay open." : ""
                    color: Colours.palette.m3onSurfaceVariant
                    wrapMode: Text.WordWrap
                }
                Row {
                    anchors { right: parent.right; bottom: parent.bottom; margins: 20 }
                    spacing: 10
                    Rectangle {
                        width: 90; height: 38; radius: 16
                        color: Colours.palette.m3surfaceContainer
                        StyledText { anchors.centerIn: parent; text: "Cancel"; color: Colours.palette.m3onSurface }
                        MouseArea { anchors.fill: parent; onClicked: root.pendingClose = null }
                    }
                    Rectangle {
                        width: 110; height: 38; radius: 16
                        color: Colours.palette.m3primary
                        StyledText { anchors.centerIn: parent; text: closeProcess.running ? "Moving…" : "Close desktop"; color: Colours.palette.m3onPrimary }
                        MouseArea { anchors.fill: parent; enabled: !closeProcess.running; onClicked: root.closeDesktop(true) }
                    }
                }
            }
        }
        Item {
            id: dragGhost
            property var draggedToplevel: root.dragWindow
            property point pointerOffset
            width: 190; height: 140
            Drag.active: root.dragging
            Drag.source: dragGhost
            Drag.keys: ["caelestia-window"]
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2
        }
        StyledClippingRect {
            id: dragVisual
            z: 1000
            visible: root.dragging
            x: root.hoverDropTarget ? root.hoverDropTarget.mapToItem(dragVisual.parent, 0, 0).x : dragGhost.x + root.returnOffsetX
            y: root.hoverDropTarget ? root.hoverDropTarget.mapToItem(dragVisual.parent, 0, 0).y : dragGhost.y + root.returnOffsetY
            width: root.hoverDropTarget ? root.hoverDropTarget.width : dragGhost.width
            height: root.hoverDropTarget ? root.hoverDropTarget.height : dragGhost.height
            radius: root.hoverDropTarget ? 16 : 18
            opacity: 1
            color: root.hoverDropTarget ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainerHigh
            border.width: 0
            Behavior on x { enabled: root.hoverDropTarget !== null; Anim {} }
            Behavior on y { enabled: root.hoverDropTarget !== null; Anim {} }
            Behavior on color { ColorAnimation { duration: Tokens.anim.durations.expressiveFastEffects; easing.type: Easing.OutCubic } }
            Behavior on width { Anim { type: Anim.FastSpatial } }
            Behavior on height { Anim { type: Anim.FastSpatial } }
            Behavior on radius { Anim { type: Anim.FastSpatial } }
            StyledClippingRect {
                x: root.hoverDropTarget ? (dragVisual.width - 20) / 2 : 10
                y: root.hoverDropTarget ? (dragVisual.height - 20) / 2 : 10
                width: root.hoverDropTarget ? 20 : dragVisual.width - 20
                height: root.hoverDropTarget ? 20 : dragVisual.height - 20
                radius: root.hoverDropTarget ? 6 : 12
                color: root.hoverDropTarget ? "transparent" : Colours.palette.m3surfaceContainerLowest
                Behavior on x { Anim { type: Anim.FastSpatial } }
                Behavior on y { Anim { type: Anim.FastSpatial } }
                Behavior on width { Anim { type: Anim.FastSpatial } }
                Behavior on height { Anim { type: Anim.FastSpatial } }
                Behavior on radius { Anim { type: Anim.FastSpatial } }
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: root.dragWindow?.wayland ?? null
                    live: root.dragging || root.dropAnimating
                    constraintSize.width: 340; constraintSize.height: 184
                    opacity: root.hoverDropTarget ? 0 : 1
                    Behavior on opacity { Anim { type: Anim.FastEffects } }
                }
            }
            CachingIconImage {
                anchors.centerIn: parent
                implicitSize: 16
                visible: root.dragging
                source: Icons.getAppIcon(root.dragWindow?.lastIpcObject.class ?? "", "application-x-executable")
                opacity: root.hoverDropTarget ? 1 : 0
                Behavior on opacity { Anim { type: Anim.FastEffects } }
            }
            StyledText {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                opacity: root.hoverDropTarget ? 0 : 1
                Behavior on opacity { Anim { type: Anim.FastEffects } }
                text: root.dragWindow?.title ?? ""
                color: Colours.palette.m3onSurface
                elide: Text.ElideRight
            }
                }
        Rectangle {
            id: panel
            anchors.centerIn: parent
            width: root.overview ? Math.min(win.width - 100, Math.max(240, monitorColumn.implicitWidth + 36, root.windows.length ? root.columns * 236 + 36 : 0)) : Math.min(win.width - 100, root.columns * 236 + 36)
            height: root.overview ? Math.min(win.height - 120, root.desktopHeaderHeight + (root.windows.length ? Math.ceil(root.windows.length / root.columns) * 220 : emptyState.implicitHeight + 16) + 58) : 244
            radius: 28
            color: Colours.palette.m3surfaceContainer
            border.width: 1
            border.color: Colours.palette.m3outlineVariant
            opacity: root.opened ? 1 : 0
            scale: 0.96 + opacity * 0.04
            Behavior on opacity { Anim { duration: 180; type: Anim.Standard } }
            Behavior on width { Anim { duration: 280; type: Anim.Standard } }
            Behavior on height { Anim { duration: 280; type: Anim.Standard } }
            MouseArea { anchors.fill: parent }
            Flickable {
                x: 18; y: 18
                width: parent.width - 36
                height: root.desktopHeaderHeight - 18
                visible: root.overview
                contentWidth: monitorColumn.width
                contentHeight: monitorColumn.height
                clip: true
                Column {
                    id: monitorColumn
                    spacing: 12
                    Repeater {
                        model: root.monitorGroups
                        delegate: Row {
                            id: monitorRow
                            required property var modelData
                            spacing: 10
                            StyledText {
                                text: monitorRow.modelData.name
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                                width: 95; height: 38
                                verticalAlignment: Text.AlignVCenter
                            }
                            Repeater {
                                model: root.desktops.filter(ws => ws.monitor?.name === monitorRow.modelData.name)
                                delegate: Rectangle {
                                    id: desktopChip
                                    required property var modelData
                                    property bool editing: false
                                    width: 142; height: 38; radius: 16
                                    color: desktopDrop.containsDrag ? Colours.palette.m3secondaryContainer : modelData.id === root.desktopId ? Colours.palette.m3primary : Colours.palette.m3surfaceContainerHigh
                                    border.width: desktopDrop.containsDrag ? 2 : 0
                                    border.color: Colours.palette.m3primary
                                    scale: root.hoverDropTarget === desktopChip ? 1.04 : 1
                                    Behavior on scale { Anim {} }
                                    Behavior on color { CAnim {} }
                                    StyledText {
                                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 8 }
                                        width: parent.width - 40
                                        visible: !desktopChip.editing
                                        text: root.desktopName(desktopChip.modelData)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                        color: desktopChip.modelData.id === root.desktopId && !desktopDrop.containsDrag ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !desktopChip.editing
                                        hoverEnabled: true
                                        onEntered: if (!root.dragging && !root.dropAnimating && !root.pendingClose && root.dropLockedDesktopId !== desktopChip.modelData.id) root.selectDesktop(desktopChip.modelData.id)
                                        onExited: if (root.dropLockedDesktopId === desktopChip.modelData.id) root.dropLockedDesktopId = -2147483648
                                        onClicked: root.selectDesktop(desktopChip.modelData.id)
                                        onDoubleClicked: {
                                            desktopChip.editing = true;
                                            editor.text = root.desktopName(desktopChip.modelData);
                                            editor.forceActiveFocus(); editor.selectAll();
                                        }
                                    }
                                    TextInput {
                                        id: editor
                                        anchors { fill: parent; margins: 7 }
                                        visible: desktopChip.editing
                                        color: desktopChip.modelData.id === root.desktopId ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                                        selectByMouse: true; clip: true
                                        horizontalAlignment: TextInput.AlignHCenter
                                        verticalAlignment: TextInput.AlignVCenter
                                        onAccepted: {
                                            root.renameDesktop(desktopChip.modelData.id, text);
                                            desktopChip.editing = false; keyReceiver.forceActiveFocus();
                                        }
                                        Keys.onEscapePressed: { desktopChip.editing = false; keyReceiver.forceActiveFocus(); }
                                    }
                                    Item {
                                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 3 }
                                        width: 30; height: 30
                                        visible: !desktopChip.editing
                                        opacity: root.desktopSiblings(desktopChip.modelData).length > 1 ? 1 : 0.3
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "×"; font.pixelSize: 20
                                            color: desktopChip.modelData.id === root.desktopId ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            enabled: root.desktopSiblings(desktopChip.modelData).length > 1 && !root.dragging && !root.dropAnimating && !moveProcess.running && !dropGuard.running
                                            onClicked: root.requestClose(desktopChip.modelData)
                                        }
                                    }
                                    DropArea {
                                        id: desktopDrop
                                        anchors.fill: parent
                                        keys: ["caelestia-window"]
                                        enabled: root.dragging && root.dragWindow !== null && (root.dragWindow.workspace?.id ?? root.dragWindow.lastIpcObject?.workspace?.id) !== desktopChip.modelData.id
                                        onEntered: { returnMorph.stop(); root.returnOffsetX = 0; root.returnOffsetY = 0; root.hoverDropTarget = desktopChip; }
                                        onExited: if (root.hoverDropTarget === desktopChip) {
                                            const visualPos = dragVisual.mapToItem(dragVisual.parent, 0, 0);
                                            root.returnOffsetX = visualPos.x - dragGhost.x;
                                            root.returnOffsetY = visualPos.y - dragGhost.y;
                                            root.hoverDropTarget = null;
                                            returnMorph.restart();
                                        }
                                        onDropped: event => {
                                            if (!root.dragWindow || (root.dragWindow.workspace?.id ?? root.dragWindow.lastIpcObject?.workspace?.id) === desktopChip.modelData.id) return;
                                            root.absorbWindow(desktopChip.modelData, desktopChip, win.contentItem);
                                            event.acceptProposedAction();
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                width: 38; height: 38; radius: 16
                                color: Colours.palette.m3surfaceContainerHigh
                                StyledText { anchors.centerIn: parent; text: "+"; color: Colours.palette.m3primary; font.pixelSize: 24 }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.createDesktop(monitorRow.modelData.name);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            StyledText {
                id: emptyState
                x: 18
                y: root.desktopHeaderHeight + 8
                width: parent.width - 36
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                visible: root.overview && root.windows.length === 0
                text: "No windows on this desktop"
                color: Colours.palette.m3onSurfaceVariant
            }
            StyledText {
                x: 18; y: parent.height - 31; width: parent.width - 170
                visible: root.overview
                text: root.moveError || "Hover to preview · drag windows between desktops · double-click a name to edit"
                color: root.moveError ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Rectangle {
                anchors { right: parent.right; bottom: parent.bottom; rightMargin: 18; bottomMargin: 9 }
                width: 118; height: 26; radius: 13
                visible: root.overview
                color: Colours.palette.m3surfaceContainerHigh
                StyledText { anchors.centerIn: parent; text: "Open desktop"; color: Colours.palette.m3primary; font.pixelSize: 12 }
                MouseArea { anchors.fill: parent; onClicked: root.enterDesktop() }
            }
            Flickable {
                id: list
                visible: root.windows.length > 0
                anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; margins: 18 }
                anchors.topMargin: root.overview ? root.desktopHeaderHeight : 18
                anchors.bottomMargin: root.overview ? 40 : 18
                clip: true
                contentWidth: root.overview ? width : Math.max(0, root.windows.length * 236 - 12)
                contentHeight: root.overview ? Math.ceil(root.windows.length / root.columns) * 220 : height
                contentX: root.overview ? 0 : Math.max(0, Math.min(contentWidth - width, root.selected * 236 - (width - 224) / 2))
                Behavior on contentX { Anim { duration: 220; type: Anim.Standard } }
                Rectangle {
                    visible: root.windows.length > 0 && root.selected >= 0 && root.selected < root.windows.length
                    x: (root.overview ? root.selected % root.columns : root.selected) * 236
                    y: root.overview ? Math.floor(root.selected / root.columns) * 220 : 0
                    width: 224; height: 208
                    radius: 20
                    color: Colours.palette.m3primaryContainer
                    border.width: 2
                    border.color: Colours.palette.m3primary
                    Behavior on x { Anim { duration: 220; type: Anim.Standard } }
                    Behavior on y { Anim { duration: 220; type: Anim.Standard } }
                }
                Repeater {
                    model: root.windows
                    delegate: Item {
                        id: card
                        required property var modelData
                        required property int index
                        x: (root.overview ? index % root.columns : index) * 236
                        y: root.overview ? Math.floor(index / root.columns) * 220 : 0
                        width: 224; height: 208
                        opacity: (root.dragging || root.dropAnimating) && root.dragWindow === modelData ? 0.25 : 1
                        Behavior on opacity { Anim { type: Anim.FastEffects } }
                        Rectangle {
                            x: 10; y: 10; width: 204; height: 140
                            radius: 14
                            color: Colours.palette.m3surfaceContainerLowest
                            clip: true
                            CachingIconImage {
                                anchors.centerIn: parent
                                implicitSize: 48
                                source: Icons.getAppIcon(card.modelData?.lastIpcObject.class ?? "", "application-x-executable")
                            }
                            ScreencopyView {
                                anchors.fill: parent
                                anchors.margins: 3
                                // A workspace with no mapped window has no
                                // capture source. Keep its tile stable instead
                                // of briefly displaying a one-pixel capture.
                                visible: card.modelData?.wayland !== null && card.modelData?.wayland !== undefined
                                captureSource: card.modelData?.wayland ?? null
                                live: root.opened
                                constraintSize.width: 408
                                constraintSize.height: 280
                            }
                            StyledText {
                                anchors.centerIn: parent
                                visible: !card.modelData?.wayland
                                text: "Empty desktop"
                                color: Colours.palette.m3onSurfaceVariant
                                font: Tokens.font.body.small
                            }
                        }
                        CachingIconImage {
                            x: 14; y: 164; implicitSize: 24
                            source: Icons.getAppIcon(card.modelData?.lastIpcObject.class ?? "", "application-x-executable")
                        }
                        StyledText {
                            x: 46; y: 162; width: 164
                            text: card.modelData?.title ?? "Closed window"
                            font: Tokens.font.body.small
                            color: root.selected === card.index ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
                            elide: Text.ElideRight
                        }
                        StyledText {
                            x: 46; y: 184; width: 164
                            text: DesktopEntries.heuristicLookup(card.modelData?.lastIpcObject.class ?? "")?.name ?? card.modelData?.lastIpcObject.class ?? ""
                            font.pixelSize: 11
                            color: Colours.palette.m3onSurfaceVariant
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            id: cardMouse
                            property bool dragged: false
                            enabled: !root.dropAnimating && !moveProcess.running
                            anchors.fill: parent
                            hoverEnabled: true
                            drag.target: root.overview ? dragGhost : null
                            drag.threshold: 10
                            onPressed: event => {
                                dragged = false;
                                if (!root.overview) return;
                                root.dragWindow = card.modelData;
                                root.dragPreviewDesktopId = root.desktopId;
                                root.hoverDropTarget = null; returnMorph.stop(); root.returnOffsetX = 0; root.returnOffsetY = 0;
                                dragGhost.scale = 1;
                                dragGhost.opacity = 0.92;
                                dragGhost.width = 190;
                                dragGhost.height = 140;
                                const pos = mapToItem(win.contentItem, event.x, event.y);
                                dragGhost.x = pos.x - dragGhost.width / 2;
                                dragGhost.y = pos.y - dragGhost.height / 2;
                            }
                            onPositionChanged: {
                                if (drag.active && root.overview) { dragged = true; root.dragging = true; }
                                else if (containsMouse && !root.dragging) root.selected = card.index;
                            }
                            onReleased: {
                                if (root.dragging) {
                                    dragGhost.Drag.drop();
                                    root.dragging = false;
                                    root.hoverDropTarget = null;
                                    if (!root.dropAnimating) root.dragWindow = null;
                                }
                            }
                            onCanceled: { root.dragging = false; if (!root.dropAnimating) root.dragWindow = null; }
                            onClicked: if (!dragged && !root.dragging) { root.selected = card.index; root.accept(); }
                        }
                    }
                }
            }
        }
    }
}
