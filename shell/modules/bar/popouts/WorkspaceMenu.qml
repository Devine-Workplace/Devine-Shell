pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root
    required property ShellScreen screen
    required property var popouts
    required property real popupRevealProgress
    required property real barHeight
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property var desktops: Hypr.workspaces.values.filter(w => !w.name.startsWith("special:") && w.monitor?.name === screen.name).sort((a,b) => a.id-b.id)
    property var names: ({})
    property int previewDesktopId: -2147483648
    property bool previewExpanded: false
    property bool dragging: false
    property var dragWindow: null
    property var hoverDropTarget: null
        readonly property var morphIconTarget: hoverDropTarget?.dropIconTarget ?? null
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
    property int dropLockedDesktopId: -2147483648
    readonly property var previewWindows: Hypr.toplevels.values.filter(w => w.workspace?.id === root.previewDesktopId && w.wayland)
    readonly property string longestLabel: desktops.map(ws => names[String(ws.id)] ?? (ws.id > 0 ? "Desktop " + ws.id : ws.name)).sort((a,b) => b.length-a.length)[0] ?? "Desktop"
    TextMetrics { id: nameMetrics; text: root.longestLabel; font: Tokens.font.body.small }
    readonly property real listWidth: Math.min(240, Math.max(190, Math.ceil(nameMetrics.advanceWidth) + 96))
    readonly property bool previewVisible: previewExpanded
    readonly property real previewBottomInset: Math.max(0, (barHeight - 32) / 2)
    implicitWidth: listWidth + (previewVisible ? 12 + 252 : 0)
    implicitHeight: leftColumn.implicitHeight

    function showPreview(id: int): void {
        if (dragging || dropAnimating || windowMove.running || dropLockedDesktopId === id) return;
        if (previewDesktopId !== id) previewList.contentY = 0;
        previewDesktopId = id;
        previewExpanded = true;
    }

    function moveWindow(window, desktop): void {
        if (!window || windowMove.running) return;
        const address = window.lastIpcObject.address ?? window.address;
        if (!address || window.workspace?.id === desktop.id) return;
        const target = desktop.id < 0 ? "name:" + desktop.name : String(desktop.id);
        dropLockedDesktopId = desktop.id;
        windowMove.command = ["python3", Paths.scripts + "/move-window.py", address, target];
        windowMove.running = true;
    }

    Process { id: windowMove }

    function absorbWindow(window, desktop, target): void {
        if (!window || (window.workspace?.id ?? window.lastIpcObject?.workspace?.id) === desktop.id) return;
        root.moveWindow(window, desktop);
        hoverDropTarget = null;
    }



    Item {
        id: dragGhost
        property var draggedToplevel: root.dragWindow
        property point pointerOffset
        width: previewList.width; height: 76
        Drag.active: root.dragging
        Drag.source: dragGhost
        Drag.keys: ["caelestia-window"]
        Drag.hotSpot.x: pointerOffset.x
        Drag.hotSpot.y: pointerOffset.y
    }
    StyledClippingRect {
        id: dragVisual
        z: 1000
        visible: root.dragging
        x: root.morphIconTarget ? root.morphIconTarget.mapToItem(root, 0, 0).x + (root.morphIconTarget.width - 22) / 2 : dragGhost.x + root.returnOffsetX
        y: root.morphIconTarget ? root.morphIconTarget.mapToItem(root, 0, 0).y + (root.morphIconTarget.height - 22) / 2 : dragGhost.y + root.returnOffsetY
        width: root.morphIconTarget ? 22 : dragGhost.width
        height: root.morphIconTarget ? 22 : dragGhost.height
        radius: root.morphIconTarget ? 6 : 18
        opacity: 1
        color: root.hoverDropTarget ? "transparent" : Colours.palette.m3surfaceContainerHigh
        border.width: 0
        Behavior on x { enabled: root.morphIconTarget !== null; Anim {} }
        Behavior on y { enabled: root.morphIconTarget !== null; Anim {} }
        Behavior on width { Anim { type: Anim.FastSpatial } }
        Behavior on height { Anim { type: Anim.FastSpatial } }
        Behavior on radius { Anim { type: Anim.FastSpatial } }
        StyledClippingRect {
            x: root.hoverDropTarget ? (dragVisual.width - 12) / 2 : 8
            y: root.hoverDropTarget ? (dragVisual.height - 12) / 2 : 8
            width: root.hoverDropTarget ? 12 : 94
            height: root.hoverDropTarget ? 12 : 60
            radius: root.hoverDropTarget ? 4 : 8
            color: root.hoverDropTarget ? "transparent" : Colours.palette.m3surfaceContainerLowest
            Behavior on x { Anim { type: Anim.FastSpatial } }
            Behavior on y { Anim { type: Anim.FastSpatial } }
            Behavior on width { Anim { type: Anim.FastSpatial } }
            Behavior on height { Anim { type: Anim.FastSpatial } }
            Behavior on radius { Anim { type: Anim.FastSpatial } }
            CachingIconImage {
                anchors.centerIn: parent
                implicitSize: 28
                visible: !dragCapture.hasContent && !root.hoverDropTarget
                source: Icons.getAppIcon(root.dragWindow?.lastIpcObject.class ?? "", "application-x-executable")
            }
            ScreencopyView {
                id: dragCapture
                anchors.centerIn: parent
                width: Math.min(parent.width - 4, sourceSize.width / Math.max(1, sourceSize.height) * (parent.height - 4))
                height: Math.min(parent.height - 4, sourceSize.height / Math.max(1, sourceSize.width) * (parent.width - 4))
                captureSource: root.dragWindow?.wayland ?? null
                live: root.dragging || root.dropAnimating
                constraintSize.width: 188; constraintSize.height: 120
                opacity: root.hoverDropTarget ? 0 : 1
                Behavior on opacity { Anim { type: Anim.FastEffects } }
            }
        }
        CachingIconImage {
            anchors.centerIn: parent
            implicitSize: 13
            visible: root.dragging
            source: Icons.getAppIcon(root.dragWindow?.lastIpcObject.class ?? "", "application-x-executable")
            opacity: root.hoverDropTarget ? 1 : 0
            Behavior on opacity { Anim { type: Anim.FastEffects } }
        }
        StyledText {
            x: 112; y: 10; width: parent.width - 122; height: 56
            opacity: root.hoverDropTarget ? 0 : 1
            Behavior on opacity { Anim { type: Anim.FastEffects } }
            text: root.dragWindow?.title ?? ""
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: Colours.palette.m3onSurface
            wrapMode: Text.Wrap
            maximumLineCount: 3
            font: Tokens.font.body.small
        }
        }

    Connections {
        target: root.popouts
        function onHasCurrentChanged() {
            if (root.popouts.hasCurrent && root.popouts.currentName === "workspaces") {
                root.previewDesktopId = -2147483648;
                root.previewExpanded = false;
            }
        }
        function onCurrentNameChanged() {
            if (root.popouts.hasCurrent && root.popouts.currentName === "workspaces") {
                root.previewDesktopId = -2147483648;
                root.previewExpanded = false;
            }
        }
    }

    FileView {
        path: Paths.config + "/workspace-names.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.names = JSON.parse(text()); } catch(e) {} }
    }

    Item {
        id: layout
        width: parent.width
        height: parent.height
        Column {
            id: leftColumn
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: root.listWidth
            spacing: 4
            StyledText {
                width: parent.width; height: 24
                text: root.screen.name + " · " + root.desktops.length + (root.desktops.length === 1 ? " desktop" : " desktops")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.body.small
            }
            Repeater {
                model: root.desktops
                delegate: Rectangle {
                    id: entry
                    required property var modelData
                    readonly property bool active: modelData.id === root.monitor?.activeWorkspace?.id
                    readonly property var openWindows: Hypr.toplevels.values.filter(w => w.workspace?.id === modelData.id && w.wayland)
                    readonly property int count: openWindows.length
                    readonly property var dropIconTarget: dropIconSlot
                    width: leftColumn.width; height: 34; radius: 12
                    color: desktopDrop.containsDrag ? Colours.palette.m3secondaryContainer : active ? Colours.palette.m3primary : hover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"
                    border.width: desktopDrop.containsDrag ? 1 : 0
                    border.color: Colours.palette.m3primary
                    scale: root.hoverDropTarget === entry ? 1.04 : 1
                    Behavior on scale { Anim {} }
                    Behavior on color { CAnim {} }
                    HoverHandler {
                        id: hover
                    }
                    StyledText {
                        x: 14; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 96
                        text: root.names[String(entry.modelData.id)] ?? (entry.modelData.id > 0 ? "Desktop " + entry.modelData.id : entry.modelData.name)
                        color: entry.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurface
                        font: Tokens.font.body.small
                        elide: Text.ElideRight
                    }
                    StyledText {
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        visible: entry.count === 0 && root.hoverDropTarget !== entry
                        text: "Empty"
                        font.pixelSize: 11
                        color: entry.active ? Colours.palette.m3onPrimary : Colours.palette.m3onSurfaceVariant
                    }
                    Item {
                        id: windowIconStack
                        anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                        width: 13; height: 27
                        CachingIconImage {
                            x: 0
                            y: entry.count > 1 ? 0 : 7
                            implicitSize: 13
                            visible: entry.count > 0
                            source: Icons.getAppIcon(entry.openWindows[0]?.lastIpcObject.class ?? "", "application-x-executable")
                            Behavior on y { Anim { type: Anim.FastSpatial } }
                        }
                        CachingIconImage {
                            x: 0; y: 14
                            implicitSize: 13
                            visible: entry.count > 1 && root.hoverDropTarget !== entry
                            source: Icons.getAppIcon(entry.openWindows[1]?.lastIpcObject.class ?? "", "application-x-executable")
                            opacity: visible ? 1 : 0
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                        }
                        Item {
                            id: dropIconSlot
                            x: 0
                            y: entry.count === 0 ? 7 : 14
                            width: 13; height: 13
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.showPreview(entry.modelData.id)
                        onExited: if (root.dropLockedDesktopId === entry.modelData.id) root.dropLockedDesktopId = -2147483648
                        onPositionChanged: if (root.previewDesktopId !== entry.modelData.id) root.showPreview(entry.modelData.id)
                        onClicked: {
                            if (root.dragging || root.dropAnimating || windowMove.running || root.dropLockedDesktopId === entry.modelData.id) return;
                            root.popouts.hasCurrent = false;
                            Hypr.focusWorkspace(entry.modelData.id);
                        }
                    }
                    DropArea {
                        id: desktopDrop
                        anchors.fill: parent
                        keys: ["caelestia-window"]
                        enabled: root.dragging && root.dragWindow !== null && (root.dragWindow.workspace?.id ?? root.dragWindow.lastIpcObject?.workspace?.id) !== entry.modelData.id
                        onEntered: { returnMorph.stop(); root.returnOffsetX = 0; root.returnOffsetY = 0; root.hoverDropTarget = entry; }
                        onExited: if (root.hoverDropTarget === entry) {
                            const visualPos = dragVisual.mapToItem(root, 0, 0);
                            root.returnOffsetX = visualPos.x - dragGhost.x;
                            root.returnOffsetY = visualPos.y - dragGhost.y;
                            root.hoverDropTarget = null;
                            returnMorph.restart();
                        }
                        onDropped: event => {
                            const window = event.source?.draggedToplevel ?? root.dragWindow;
                            if (!window || (window.workspace?.id ?? window.lastIpcObject?.workspace?.id) === entry.modelData.id) return;
                            root.absorbWindow(window, entry.modelData, entry);
                            event.acceptProposedAction();
                        }
                    }
                }
            }
            Rectangle {
                width: leftColumn.width; height: 32; radius: 12
                color: newHover.hovered ? Colours.palette.m3surfaceContainerHigh : "transparent"
                HoverHandler { id: newHover }
                StyledText { anchors.centerIn: parent; text: "+ New desktop"; color: Colours.palette.m3primary; font: Tokens.font.body.small }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.popouts.hasCurrent = false;
                        Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "switcher", "createDesktop", root.screen.name]);
                    }
                }
            }
            StyledText {
                width: leftColumn.width; height: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: "Manage all displays"
                color: Colours.palette.m3onSurfaceVariant
                font.pixelSize: 11
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.popouts.hasCurrent = false;
                        Quickshell.execDetached(["qs", "-c", "caelestia", "ipc", "call", "switcher", "overview"]);
                    }
                }
            }
        }

        Item {
            id: previewPanel
            x: root.listWidth + 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: -8 - root.barHeight
            visible: root.previewVisible
            width: 252
            implicitWidth: width
            implicitHeight: leftColumn.implicitHeight
            height: implicitHeight + 8 + root.barHeight
            opacity: visible ? 1 : 0
            Behavior on opacity { Anim { duration: 140; type: Anim.Standard } }
            clip: true

            StyledText {
                id: header
                x: 12; y: 10; width: parent.width - 24; height: 22
                text: {
                    const ws = root.desktops.find(d => d.id === root.previewDesktopId);
                    return ws ? (root.names[String(ws.id)] ?? (ws.id > 0 ? "Desktop " + ws.id : ws.name)) : "Desktop";
                }
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
                elide: Text.ElideRight
            }
            StyledClippingRect {
                x: 10; y: 38
                width: parent.width - 20
                height: Math.max(24, parent.height - 38 - root.previewBottomInset)
                radius: 12

            Flickable {
                id: previewList
                anchors.fill: parent
                clip: true
                contentWidth: width
                contentHeight: root.previewWindows.length ? windowsColumn.implicitHeight : emptyLabel.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                Controls.ScrollBar.vertical: Controls.ScrollBar {
                    width: 4
                    policy: Controls.ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 2
                        color: Colours.palette.m3primary
                    }
                    background: Item {}
                }
                Column {
                    id: windowsColumn
                    width: previewList.width
                    spacing: 6
                    Repeater {
                        model: root.previewWindows
                        delegate: Rectangle {
                            id: windowRow
                            required property var modelData
                            width: windowsColumn.width; height: 76; radius: 12
                            color: Colours.palette.m3surfaceContainerHigh
                            opacity: (root.dragging || root.dropAnimating) && root.dragWindow === modelData ? 0.25 : 1
                            Behavior on opacity { Anim { type: Anim.FastEffects } }
                            Rectangle {
                                x: 8; y: 8; width: 94; height: 60; radius: 8
                                color: Colours.palette.m3surfaceContainerLowest
                                clip: true
                                CachingIconImage {
                                    anchors.centerIn: parent
                                    implicitSize: 28
                                    visible: !windowCapture.hasContent
                                    source: Icons.getAppIcon(windowRow.modelData.lastIpcObject.class ?? "", "application-x-executable")
                                }
                                ScreencopyView {
                                    id: windowCapture
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width - 4, (sourceSize.width / Math.max(1, sourceSize.height)) * (parent.height - 4))
                                    height: Math.min(parent.height - 4, (sourceSize.height / Math.max(1, sourceSize.width)) * (parent.width - 4))
                                    captureSource: windowRow.modelData.wayland
                                    live: root.previewVisible && root.popouts.hasCurrent
                                    constraintSize.width: 188
                                    constraintSize.height: 120
                                }
                            }
                            StyledText {
                                x: 112; y: 10; width: parent.width - 122; height: 56
                                text: windowRow.modelData.title || DesktopEntries.heuristicLookup(windowRow.modelData.lastIpcObject.class ?? "")?.name || "Open window"
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.small
                                wrapMode: Text.Wrap
                                elide: Text.ElideRight
                                maximumLineCount: 3
                            }
                            MouseArea {
                                id: windowDrag
                                enabled: !root.dropAnimating && !windowMove.running
                                anchors.fill: parent
                                drag.target: dragGhost
                                drag.threshold: 10
                                drag.filterChildren: true
                                preventStealing: true
                                onPressed: event => {
                                    root.dragWindow = windowRow.modelData;
                                    root.hoverDropTarget = null; returnMorph.stop(); root.returnOffsetX = 0; root.returnOffsetY = 0;
                                    const position = windowRow.mapToItem(root, 0, 0);
                                    dragGhost.x = position.x;
                                    dragGhost.y = position.y;
                                    dragGhost.pointerOffset = Qt.point(event.x, event.y);
                                    dragGhost.scale = 1;
                                    dragGhost.opacity = 1;
                                    dragGhost.width = previewList.width;
                                    dragGhost.height = 76;
                                }
                                onPositionChanged: if (drag.active) root.dragging = true
                                onReleased: {
                                    if (root.dragging) dragGhost.Drag.drop();
                                    root.dragging = false;
                                    root.hoverDropTarget = null;
                                    if (!root.dropAnimating) root.dragWindow = null;
                                }
                                onCanceled: { root.dragging = false; if (!root.dropAnimating) root.dragWindow = null; }
                            }
                        }
                    }
                }
                StyledText {
                    id: emptyLabel
                    anchors.centerIn: parent
                    visible: root.previewWindows.length === 0
                    text: "No open windows"
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }
            }
        }
    }
}
