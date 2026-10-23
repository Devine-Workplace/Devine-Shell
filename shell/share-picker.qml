pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Devine.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

ShellRoot {
    id: root

    property string tab: "screen"
    property bool allowRestore: true
    property bool finishing: false
    property int selectionIndex: 0
    property string startMonitorName: ""
    readonly property var screens: Hypr.monitors.values
    readonly property var windows: {
        const raw = Quickshell.env("XDPH_WINDOW_SHARING_LIST") || "";
        return raw.split("[HA>]").filter(entry => entry.length > 0).map(entry => {
            const idAndRest = entry.split("[HC>]");
            if (idAndRest.length < 2)
                return null;
            const classAndRest = idAndRest[1].split("[HT>]");
            if (classAndRest.length < 2)
                return null;
            return {
                id: idAndRest[0],
                app: classAndRest[0],
                title: classAndRest[1].split("[HE>]")[0]
            };
        }).filter(entry => entry !== null);
    }

    function choose(value: string): void {
        if (finishing)
            return;
        finishing = true;
        resultWriter.write(`[SELECTION]${allowRestore ? "r" : ""}/${value}\n`);
    }

    function cancel(): void {
        if (finishing)
            return;
        finishing = true;
        resultWriter.write("__CANCEL__");
    }

    function chooseRegion(value: string): void {
        const parts = value.trim().split(/\s+/);
        if (parts.length !== 5 || Number(parts[3]) <= 0 || Number(parts[4]) <= 0)
            return;
        const monitor = screens.find(screen => screen.name === parts[0]);
        if (!monitor)
            return;
        const x = Number(parts[1]) - monitor.x;
        const y = Number(parts[2]) - monitor.y;
        choose(`region:${parts[0]}@${x},${y},${parts[3]},${parts[4]}`);
    }

    function selectRegion(): void {
        picker.visible = false;
        regionDelay.start();
    }

    function chooseCurrent(): void {
        const selected = tab === "screen" ? screens[selectionIndex] : windows[selectionIndex];
        if (!selected)
            return;
        choose(tab === "screen" ? `screen:${selected.name}` : `window:${selected.id}`);
    }

    function moveSelection(delta: int): void {
        const count = tab === "screen" ? screens.length : tab === "window" ? windows.length : 0;
        if (count > 0)
            selectionIndex = (selectionIndex + delta + count) % count;
    }

    Component.onCompleted: startMonitorName = Hypr.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? ""

    Process {
        id: resultWriter
        property string resultPath: Quickshell.env("DEVINE_PICKER_RESULT_FILE") || ""
        function write(value: string): void {
            command = ["sh", "-c", "printf '%s' \"$1\" > \"$2\"", "sh", value, resultPath];
            running = true;
        }
        onExited: Qt.quit()
    }

    Timer {
        id: regionDelay
        interval: 180
        onTriggered: regionProcess.running = true
    }

    Process {
        id: regionProcess
        command: ["slurp", "-f", "%o %x %y %w %h"]
        stdout: StdioCollector {
            id: regionOutput
        }
        onExited: code => {
            if (code === 0)
                root.chooseRegion(regionOutput.text);
            else
                picker.visible = true;
        }
    }

    StyledWindow {
        id: picker

        name: "share-picker"
        screen: Quickshell.screens.find(candidate => candidate.name === root.startMonitorName) ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(Colours.palette.m3scrim, 0.55)

            MouseArea {
                anchors.fill: parent
                onClicked: root.cancel()
            }
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(590, parent.width - Tokens.padding.large * 2)
            height: Math.min(500, parent.height - Tokens.padding.large * 2)
            color: Colours.tPalette.m3surface
            radius: Tokens.rounding.extraLarge
            border.width: 1
            border.color: Colours.palette.m3outlineVariant

            focus: true
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.cancel();
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_1) {
                    root.tab = "screen";
                    root.selectionIndex = 0;
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_2) {
                    root.tab = "window";
                    root.selectionIndex = 0;
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_3) {
                    root.tab = "region";
                    root.selectionIndex = 0;
                } else if (event.key === Qt.Key_Down) {
                    root.moveSelection(1);
                } else if (event.key === Qt.Key_Up) {
                    root.moveSelection(-1);
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (root.tab === "region")
                        root.selectRegion();
                    else
                        root.chooseCurrent();
                } else {
                    event.accepted = false;
                    return;
                }
                event.accepted = true;
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tokens.padding.large
                spacing: Tokens.spacing.medium

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48

                    MaterialIcon {
                        id: shareIcon
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "screen_share"
                        fontStyle: Tokens.font.icon.large
                        fill: 1
                        color: Colours.palette.m3primary
                    }

                    ColumnLayout {
                        anchors.left: shareIcon.right
                        anchors.leftMargin: Tokens.spacing.medium
                        anchors.right: closeButton.left
                        anchors.rightMargin: Tokens.spacing.small
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: "Choose what to share"
                            font: Tokens.font.title.medium
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Select a screen, window, or area for this app."
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        id: closeButton
                        anchors.top: parent.top
                        anchors.right: parent.right
                        width: 40
                        height: 40
                        icon: "close"
                        onClicked: root.cancel()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        model: [
                            {
                                id: "screen",
                                label: "Screens",
                                icon: "desktop_windows"
                            },
                            {
                                id: "window",
                                label: "Windows",
                                icon: "window"
                            },
                            {
                                id: "region",
                                label: "Area",
                                icon: "crop_free"
                            }
                        ]

                        delegate: ButtonBase {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitWidth: 120
                            implicitHeight: 40
                            isToggle: true
                            checked: root.tab === modelData.id
                            activeColour: Colours.palette.m3secondaryContainer
                            inactiveColour: Colours.tPalette.m3surfaceContainer
                            activeOnColour: Colours.palette.m3onSecondaryContainer
                            inactiveOnColour: Colours.palette.m3onSurfaceVariant

                            Row {
                                anchors.centerIn: parent
                                spacing: Tokens.spacing.small

                                MaterialIcon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    fontStyle: Tokens.font.icon.small
                                    fill: 1
                                    color: parent.parent.onColour
                                }

                                StyledText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: parent.parent.onColour
                                    font: Tokens.font.label.large
                                }
                            }

                            onClicked: {
                                root.tab = modelData.id;
                                root.selectionIndex = 0;
                            }
                        }
                    }
                }

                StyledClippingRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: Tokens.rounding.large
                    color: Colours.tPalette.m3surfaceContainerLow

                    Flickable {
                        anchors.fill: parent
                        anchors.margins: Tokens.padding.small
                        clip: true
                        contentWidth: width
                        contentHeight: choices.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: choices
                            width: parent.width
                            spacing: Tokens.spacing.small

                            Repeater {
                                model: root.tab === "screen" ? root.screens : root.tab === "window" ? root.windows : []

                                delegate: ButtonBase {
                                    id: choice
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitWidth: 300
                                    implicitHeight: 64
                                    padding: Tokens.padding.medium
                                    horizontalPadding: Tokens.padding.medium
                                    verticalPadding: Tokens.padding.small
                                    activeColour: Colours.palette.m3primaryContainer
                                    inactiveColour: Colours.tPalette.m3surfaceContainer
                                    activeOnColour: Colours.palette.m3onPrimaryContainer
                                    inactiveOnColour: Colours.palette.m3onSurface
                                    checked: root.selectionIndex === index

                                    RowLayout {
                                        anchors.fill: parent
                                        spacing: Tokens.spacing.medium

                                        MaterialIcon {
                                            text: root.tab === "screen" ? "monitor" : Icons.getAppCategoryIcon(choice.modelData.app, "window")
                                            fontStyle: Tokens.font.icon.medium
                                            fill: 1
                                            color: choice.onColour
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: root.tab === "screen" ? choice.modelData.name : choice.modelData.title
                                                font: Tokens.font.title.small
                                                color: choice.onColour
                                                elide: Text.ElideRight
                                            }

                                            StyledText {
                                                Layout.fillWidth: true
                                                text: root.tab === "screen" ? `${choice.modelData.width} × ${choice.modelData.height} · ${choice.modelData.x}, ${choice.modelData.y}` : choice.modelData.app
                                                color: Colours.palette.m3onSurfaceVariant
                                                font: Tokens.font.body.small
                                                elide: Text.ElideRight
                                            }
                                        }

                                        MaterialIcon {
                                            text: "arrow_forward"
                                            fontStyle: Tokens.font.icon.small
                                            fill: 1
                                            color: choice.onColour
                                        }
                                    }

                                    onClicked: {
                                        root.selectionIndex = index;
                                    }
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                implicitHeight: root.tab === "region" || (root.tab === "window" && root.windows.length === 0) || (root.tab === "screen" && root.screens.length === 0) ? 140 : 0

                                Column {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small
                                    visible: parent.implicitHeight > 0

                                    MaterialIcon {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.tab === "region" ? "crop_free" : "desktop_access_disabled"
                                        fontStyle: Tokens.font.icon.large
                                        fill: 1
                                        color: Colours.palette.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.tab === "region" ? "Choose an area to share" : "No shareable sources found"
                                        color: Colours.palette.m3onSurfaceVariant
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    ButtonBase {
                        implicitWidth: 20
                        implicitHeight: 20
                        radius: Tokens.rounding.extraSmall
                        color: root.allowRestore ? Colours.palette.m3primary : Colours.tPalette.m3surfaceContainerHigh
                        border.width: 1
                        border.color: root.allowRestore ? Colours.palette.m3primary : Colours.palette.m3outline

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: root.allowRestore
                            text: "check"
                            fontStyle: Tokens.font.icon.small
                            fill: 1
                            color: Colours.palette.m3onPrimary
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.allowRestore = !root.allowRestore
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: "Allow this app to remember your choice"
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.small
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.allowRestore = !root.allowRestore
                        }
                    }

                    TextButton {
                        text: "Cancel"
                        type: ButtonBase.Text
                        onClicked: root.cancel()
                    }

                    TextButton {
                        text: root.tab === "region" ? "Select area" : "Make selection"
                        enabled: root.tab === "region" || (root.tab === "screen" ? root.screens.length > 0 : root.windows.length > 0)
                        onClicked: root.tab === "region" ? root.selectRegion() : root.chooseCurrent()
                    }
                }
            }
        }
    }
}
