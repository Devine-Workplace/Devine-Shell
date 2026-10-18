pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.containers
import qs.components.misc
import qs.services

Scope {
    id: pickerScope
    property bool borderHidden: false
    function prepare(): void {
        borderHidden = true;
        hideBorder.running = true;
    }
    Process {
        id: hideBorder
        command: ["hyprctl", "eval", 'hl.config({general={col={active_border="rgba(00000000)"}}})']
        onExited: captureDelay.restart()
    }
    Timer {
        id: captureDelay
        interval: 120
        onTriggered: root.activeAsync = true
    }
    Component.onDestruction: {
        if (borderHidden) Quickshell.execDetached(["hyprctl", "reload"]);
    }
    Process { id: restoreBorder; command: ["hyprctl", "reload"] }

    LazyLoader {
        id: root

        onActiveChanged: {
            if (!active && pickerScope.borderHidden) {
                pickerScope.borderHidden = false;
                restoreBorder.running = true;
            }
        }

        property bool freeze
        property bool closing
        property bool clipboardOnly

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData

                screen: modelData
                name: "area-picker"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive
                mask: root.closing ? empty : null

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Region {
                    id: empty
                }

                Picker {
                    loader: root
                    screen: win.modelData
                }
            }
        }
    }

    IpcHandler {
        function cancel(): void {
            captureDelay.stop();
            if (!root.active && pickerScope.borderHidden) {
                pickerScope.borderHidden = false;
                restoreBorder.running = true;
            }
            root.closing = true;
            root.activeAsync = false;
        }
        function open(): void {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            pickerScope.prepare();
        }

        function openFreeze(): void {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            pickerScope.prepare();
        }

        function openClip(): void {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            pickerScope.prepare();
        }

        function openFreezeClip(): void {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            pickerScope.prepare();
        }

        target: "picker"
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshot"
        description: "Open screenshot tool"
        onPressed: {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = false;
            pickerScope.prepare();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotFreeze"
        description: "Open screenshot tool (freeze mode)"
        onPressed: {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = false;
            pickerScope.prepare();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotClip"
        description: "Open screenshot tool (clipboard)"
        onPressed: {
            root.freeze = false;
            root.closing = false;
            root.clipboardOnly = true;
            pickerScope.prepare();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "screenshotFreezeClip"
        description: "Open screenshot tool (freeze mode, clipboard)"
        onPressed: {
            root.freeze = true;
            root.closing = false;
            root.clipboardOnly = true;
            pickerScope.prepare();
        }
    }
}
