pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Devine
import Devine.Config
import Devine.I18n
import qs.components
import qs.components.effects
import qs.services
import qs.utils

MouseArea {
    id: root

    required property LazyLoader loader
    required property ShellScreen screen

    property rect freeSelection: Qt.rect(0, 0, 0, 0)
    property bool freeSelectionSaved: false
    property bool freeDrag: false
    property bool controlHeld: false
    property bool morphing: false
    Timer { id: morphTimer; interval: 240; onTriggered: root.morphing = false }
    property bool onClient

    property real realBorderWidth: onClient ? (Hypr.options["general:border_size"] ?? 1) : 2
    property real realRounding: onClient ? Config.border.rounding : 0

    property real ssx
    property real ssy

    property real sx: 0
    property real sy: 0
    property real ex: 0
    property real ey: 0

    property real rsx: Math.min(sx, ex)
    property real rsy: Math.min(sy, ey)
    property real sw: Math.abs(sx - ex)
    property real sh: Math.abs(sy - ey)

    property list<var> clients: {
        const mon = Hypr.monitorFor(screen);
        if (!mon)
            return [];

        const special = mon.lastIpcObject?.specialWorkspace;
        const wsId = special?.name ? special.id : mon.activeWorkspace?.id;
        if (wsId === undefined)
            return [];

        return Hypr.toplevelsForWs(wsId).sort((a, b) => {
            // Pinned first, then fullscreen, then floating, then any other
            const ac = a?.lastIpcObject;
            const bc = b?.lastIpcObject;
            if (!ac || !bc)
                return !ac - !bc; // Missing IPC last
            return (bc.pinned - ac.pinned) || ((bc.fullscreen !== 0) - (ac.fullscreen !== 0)) || (bc.floating - ac.floating);
        });
    }

    function resetSelection(): void {
        onClient = false;
        sx = ex = Math.max(0, Math.min(screen.width, mouseX));
        sy = ey = Math.max(0, Math.min(screen.height, mouseY));
    }

    function setControlHeld(held: bool): void {
        if (held === controlHeld) return;
        morphing = true;
        morphTimer.restart();
        if (held) {
            freeSelection = Qt.rect(sx, sy, ex - sx, ey - sy);
            freeSelectionSaved = true;
            controlHeld = true;
            checkClientRects(mouseX, mouseY);
        } else {
            controlHeld = false;
            onClient = false;
            if (freeSelectionSaved) {
                sx = freeSelection.x;
                sy = freeSelection.y;
                ex = freeSelection.x + freeSelection.width;
                ey = freeSelection.y + freeSelection.height;
            }
            freeSelectionSaved = false;
        }
    }

    function checkClientRects(x: real, y: real): void {
        if (!controlHeld) return;
        resetSelection();
        for (const client of clients) {
            if (!client)
                continue;

            const ipc = client.lastIpcObject;
            if (!ipc?.at || !ipc?.size)
                continue;

            let {
                at: [cx, cy],
                size: [cw, ch]
            } = ipc;
            cx -= screen.x;
            cy -= screen.y;
            if (cx <= x && cy <= y && cx + cw >= x && cy + ch >= y) {
                onClient = true;
                sx = Math.max(0, cx);
                sy = Math.max(0, cy);
                ex = Math.min(screen.width, cx + cw);
                ey = Math.min(screen.height, cy + ch);
                break;
            }
        }
    }

    function save(): void {
        const tmpfile = Qt.resolvedUrl(`/tmp/devine-picker-${Quickshell.processId}-${Date.now()}.png`);
        // Capture the target geometry, not an in-between animated highlight.
        const crop = Qt.rect(Math.ceil(Math.min(sx, ex)), Math.ceil(Math.min(sy, ey)), Math.floor(Math.abs(ex - sx)), Math.floor(Math.abs(ey - sy)));
        if (crop.width < 2 || crop.height < 2) return;
        CUtils.saveItem(screencopy, tmpfile, crop, path => {
            if (root.loader.clipboardOnly) {
                Quickshell.execDetached(["sh", "-c", "wl-copy --type image/png < " + path]);
                Quickshell.execDetached(["notify-send", "-a", "Devine", "-i", path, Tr.tr("Screenshot taken"), Tr.tr("Screenshot copied to clipboard")]);
            } else {
                Quickshell.execDetached([Paths.scripts + "/themed-swash.py", path]);
            }
            closeAnim.start();
        });
    }

    onClientsChanged: { if (controlHeld) checkClientRects(mouseX, mouseY); }

    anchors.fill: parent
    opacity: 0
    hoverEnabled: true
    cursorShape: Qt.CrossCursor

    Component.onCompleted: {
        Hypr.extras.refreshOptions();

        // Break binding if frozen
        if (loader.freeze)
            clients = clients;

        opacity = 1;

        resetSelection();
    }

    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onPressed: event => {
        if (event.button === Qt.RightButton) {
            closeAnim.start();
            return;
        }
        setControlHeld((event.modifiers & Qt.ControlModifier) !== 0);
        ssx = event.x;
        ssy = event.y;
        freeDrag = !controlHeld;
        if (controlHeld) checkClientRects(event.x, event.y);
        else resetSelection();
    }

    onReleased: event => {
        if (event.button !== Qt.LeftButton) return;
        const wasFreeDrag = freeDrag;
        freeDrag = false;
        if (closeAnim.running) return;
        if (sw < 2 || sh < 2) {
            if (controlHeld) checkClientRects(mouseX, mouseY);
            return;
        }
        if (controlHeld && !onClient) return;
        if (root.loader.freeze) {
            save();
        } else {
            overlay.visible = border.visible = false;
            screencopy.visible = false;
            screencopy.active = true;
        }
    }

    onPositionChanged: event => {
        setControlHeld((event.modifiers & Qt.ControlModifier) !== 0);
        if (controlHeld) {
            checkClientRects(event.x, event.y);
        } else if (pressed && (pressedButtons & Qt.LeftButton)) {
            onClient = false;
            sx = Math.max(0, Math.min(screen.width, ssx));
            sy = Math.max(0, Math.min(screen.height, ssy));
            ex = Math.max(0, Math.min(screen.width, event.x));
            ey = Math.max(0, Math.min(screen.height, event.y));
        } else if (onClient) {
            resetSelection();
        }
    }

    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            closeAnim.start();
            event.accepted = true;
        } else if (event.key === Qt.Key_Control) {
            setControlHeld(true);
            event.accepted = true;
        }
    }
    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control) {
            setControlHeld(false);
            event.accepted = true;
        }
    }

    SequentialAnimation {
        id: closeAnim

        PropertyAction {
            target: root.loader
            property: "closing"
            value: true
        }
        Anim {
            target: root
            property: "opacity"
            to: 0
            type: Anim.StandardLarge
        }
        PropertyAction {
            target: root.loader
            property: "activeAsync"
            value: false
        }
    }

    Process {
        running: true
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const pos = JSON.parse(text);
                if (root.controlHeld) root.checkClientRects(pos.x - root.screen.x, pos.y - root.screen.y);
            }
        }
    }

    Loader {
        id: screencopy

        asynchronous: true
        anchors.fill: parent

        active: root.loader.freeze

        sourceComponent: ScreencopyView {
            captureSource: root.screen
            live: false

            onHasContentChanged: {
                if (hasContent && !root.loader.freeze) {
                    overlay.visible = border.visible = true;
                    root.save();
                }
            }
        }
    }

    StyledRect {
        id: overlay

        anchors.fill: parent
        color: Colours.palette.m3secondaryContainer
        opacity: 0.3

        layer.enabled: true
        layer.effect: Mask {
            maskSource: selectionWrapper
            maskInverted: true
        }
    }

    Item {
        id: selectionWrapper

        anchors.fill: parent
        layer.enabled: true
        visible: false

        Rectangle {
            id: selectionRect

            radius: root.realRounding
            x: root.rsx
            y: root.rsy
            implicitWidth: root.sw
            implicitHeight: root.sh
        }
    }

    Rectangle {
        id: border
        visible: root.sw >= 2 && root.sh >= 2

        color: "transparent"
        radius: root.realRounding > 0 ? root.realRounding + root.realBorderWidth : 0
        border.width: root.realBorderWidth
        border.color: Colours.palette.m3primary

        x: selectionRect.x - root.realBorderWidth
        y: selectionRect.y - root.realBorderWidth
        implicitWidth: selectionRect.implicitWidth + root.realBorderWidth * 2
        implicitHeight: selectionRect.implicitHeight + root.realBorderWidth * 2

        Behavior on border.color {
            CAnim {}
        }
    }

    Behavior on opacity {
        Anim {
            type: Anim.StandardLarge
        }
    }

    Behavior on realRounding {
        Anim { duration: 220 }
    }

    Behavior on rsx {
        enabled: !root.pressed || root.controlHeld || root.morphing

        Anim {}
    }

    Behavior on rsy {
        enabled: !root.pressed || root.controlHeld || root.morphing

        Anim {}
    }

    Behavior on sw {
        enabled: !root.pressed || root.controlHeld || root.morphing

        Anim {}
    }

    Behavior on sh {
        enabled: !root.pressed || root.controlHeld || root.morphing

        Anim {}
    }
}
