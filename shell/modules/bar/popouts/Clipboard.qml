pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Devine.Config
import Devine.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

StyledClippingRect {
    id: root

    signal closed
    property bool deleteMode: false
    property string query: ""
    property string errorText: ""
    property var entries: []

    readonly property var filteredEntries: entries.filter(entry => entry.preview.toLowerCase().includes(query.trim().toLowerCase()))
    readonly property string cacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/devine/clipboard"

    implicitWidth: 500
    implicitHeight: 570
    radius: Tokens.rounding.extraLarge
    color: Colours.tPalette.m3surfaceContainerHigh

    function refresh(): void {
        if (!listProcess.running) {
            errorText = "";
            listProcess.running = true;
        }
    }

    function useEntry(entry): void {
        if (deleteMode) {
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", entry.raw]);
            refreshTimer.restart();
        } else {
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entry.raw]);
            closed();
        }
    }

    Process {
        id: listProcess
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(line => line.length > 0).map(line => {
                    const tab = line.indexOf("\t");
                    const preview = tab < 0 ? line : line.slice(tab + 1);
                    const imageMatch = preview.match(/\[\[ binary data .*? (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]/i);
                    const binaryMatch = preview.match(/\[\[ binary data .*? \]\]/i);
                    const replacementCount = (preview.match(/\uFFFD/g) || []).length;
                    const unreadable = replacementCount > 3 && replacementCount / Math.max(1, preview.length) > 0.04;
                    const cleanPreview = preview.replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F-\u009F]/g, " ").replace(/\\n/g, " ").replace(/\\t/g, " ").replace(/\s+/g, " ").trim();
                    return {
                        id: (line.match(/^(\d+)/) || ["", "0"])[1],
                        raw: line,
                        image: ClipboardSettings.showImagePreviews && imageMatch !== null,
                        binary: binaryMatch !== null,
                        extension: imageMatch ? imageMatch[1].toLowerCase().replace("jpeg", "jpg") : "png",
                        dimensions: imageMatch ? imageMatch[2] : "",
                        preview: imageMatch ? Tr.tr("Image") : binaryMatch ? Tr.tr("File") : unreadable ? Tr.tr("Unsupported clipboard data") : cleanPreview || Tr.tr("Image or file")
                    };
                });
            }
        }
        onExited: exitCode => {
            if (exitCode !== 0)
                root.errorText = Tr.tr("Clipboard history is unavailable.");
        }
    }

    Timer {
        id: refreshTimer
        interval: 300
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Tokens.padding.medium
        spacing: Tokens.spacing.medium

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.medium

            StyledClippingRect {
                Layout.preferredWidth: 46
                Layout.preferredHeight: 46
                radius: Tokens.rounding.large
                color: Colours.palette.m3primaryContainer

                MaterialIcon {
                    anchors.centerIn: parent
                    text: root.deleteMode ? "delete_outline" : "content_paste"
                    fontStyle: Tokens.font.icon.medium
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("Clipboard")
                    color: Colours.palette.m3onSurface
                    font: Tokens.font.title.medium
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.deleteMode ? Tr.tr("Choose an item to remove") : `${root.filteredEntries.length} ${Tr.tr("items")}`
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.small
                }
            }

            IconButton {
                icon: "refresh"
                type: IconButton.Text
                onClicked: root.refresh()
            }
            IconButton {
                icon: "close"
                type: IconButton.Text
                onClicked: root.closed()
            }
        }

        SearchBar {
            Layout.fillWidth: true
            placeholderText: Tr.tr("Search clipboard")
            onTextChanged: root.query = text
        }

        ListView {
            id: historyList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Tokens.spacing.small
            model: root.filteredEntries
            boundsBehavior: Flickable.StopAtBounds
            StyledScrollBar.vertical: StyledScrollBar {
                flickable: historyList
            }

            delegate: StyledClippingRect {
                id: entryCard
                required property var modelData
                width: ListView.view.width
                height: modelData.image ? 112 : 82
                radius: Tokens.rounding.large
                color: hover.hovered ? Colours.palette.m3surfaceContainerHigh : Colours.tPalette.m3surfaceContainer

                HoverHandler { id: hover }
                Behavior on color { CAnim {} }

                Process {
                    id: imageDecoder
                    property bool ready: false
                    command: ["sh", "-c", "mkdir -p -- \"$1\" && printf '%s\\n' \"$2\" | cliphist decode > \"$3\"", "sh", root.cacheDir, entryCard.modelData.raw, `${root.cacheDir}/${entryCard.modelData.id}.${entryCard.modelData.extension}`]
                    running: entryCard.modelData.image
                    onExited: code => ready = code === 0
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tokens.padding.small
                    anchors.rightMargin: Tokens.padding.medium
                    anchors.topMargin: Tokens.padding.small
                    anchors.bottomMargin: Tokens.padding.small
                    spacing: Tokens.spacing.medium

                    StyledClippingRect {
                        visible: entryCard.modelData.image
                        Layout.preferredWidth: visible ? 136 : 0
                        Layout.fillHeight: visible
                        radius: Tokens.rounding.medium
                        color: Colours.tPalette.m3surfaceContainerLowest

                        Image {
                            anchors.fill: parent
                            anchors.margins: 4
                            visible: imageDecoder.ready
                            source: visible ? `file://${root.cacheDir}/${entryCard.modelData.id}.${entryCard.modelData.extension}` : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: true
                        }

                        MaterialIcon {
                            anchors.centerIn: parent
                            visible: !imageDecoder.ready
                            text: "image"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: Tokens.spacing.extraSmall

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Tokens.spacing.small

                            MaterialIcon {
                                visible: !entryCard.modelData.image
                                text: entryCard.modelData.binary ? "insert_drive_file" : "content_copy"
                                fontStyle: Tokens.font.icon.small
                                color: Colours.palette.m3primary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: entryCard.modelData.image ? Tr.tr("Image") : entryCard.modelData.preview
                                color: Colours.palette.m3onSurface
                                font: Tokens.font.body.medium
                                elide: Text.ElideRight
                                maximumLineCount: entryCard.modelData.image ? 1 : 3
                                wrapMode: Text.Wrap
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: entryCard.modelData.image
                            text: entryCard.modelData.dimensions
                            color: Colours.palette.m3onSurfaceVariant
                            font: Tokens.font.body.small
                        }
                    }

                    MaterialIcon {
                        text: root.deleteMode ? "delete_outline" : "north_west"
                        color: root.deleteMode ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
                    }
                }

                StateLayer {
                    onClicked: root.useEntry(entryCard.modelData)
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.errorText.length > 0 || root.filteredEntries.length === 0
            text: root.errorText || (root.query ? Tr.tr("No matches") : Tr.tr("Clipboard history is empty"))
            color: root.errorText ? Colours.palette.m3error : Colours.palette.m3onSurfaceVariant
            font: Tokens.font.body.small
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
