pragma Singleton

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Devine.Config
import Devine.I18n
import Devine.Models
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.utils

Singleton {
    id: root

    property string homePath: Quickshell.env("HOME") || "/"
    property var currentWindow: null

    function open(): void {
        if (currentWindow) {
            currentWindow.visible = true;
            const window = Hypr.toplevels.values.find(w => w.lastIpcObject?.class === "org.quickshell" && w.lastIpcObject?.title === currentWindow.title);
            window?.wayland?.activate();
            return;
        }
        currentWindow = explorer.createObject(dummy, {
            currentPath: homePath
        });
    }

    QtObject {
        id: dummy
    }

    Component {
        id: explorer

        FloatingWindow {
            id: win
            objectName: "devineExplorer"
            property string currentPath
            property string contextPath: ""
            property var contextEntry: null
            property real contextX: 0
            property real contextY: 0
            property bool contextOpen: false
            property bool folderDialogOpen: false
            property bool renameDialogOpen: false
            property bool showHiddenFiles: false
            property string folderError: ""
            color: Colours.tPalette.m3surface
            surfaceFormat.opaque: false
            implicitWidth: 900
            implicitHeight: 620
            minimumSize.width: 560
            minimumSize.height: 400
            title: Tr.tr("Files")

            function createFolder(): void {
                const name = folderName.text.trim();
                if (!name || name === "." || name === ".." || name.includes("/")) {
                    folderError = Tr.tr("Enter a valid folder name.");
                    return;
                }
                folderError = "";
                createFolderProcess.command = ["mkdir", "--", `${currentPath}/${name}`];
                createFolderProcess.running = true;
            }

            function renameEntry(): void {
                const name = renameName.text.trim();
                if (!name || name === "." || name === ".." || name.includes("/")) {
                    folderError = Tr.tr("Enter a valid name.");
                    return;
                }
                const destination = `${currentPath}/${name}`;
                if (destination === contextEntry?.path) {
                    renameDialogOpen = false;
                    return;
                }
                folderError = "";
                renameProcess.command = ["sh", "-c", "[ ! -e \"$2\" ] && [ ! -L \"$2\" ] || exit 17; mv -- \"$1\" \"$2\"", "sh", contextEntry.path, destination];
                renameProcess.running = true;
            }

            Process {
                id: createFolderProcess
                onExited: exitCode => {
                    if (exitCode === 0) {
                        win.folderDialogOpen = false;
                        folderName.text = "";
                    } else {
                        win.folderError = Tr.tr("Could not create the folder.");
                    }
                }
            }
            Process {
                id: renameProcess
                onExited: exitCode => {
                    if (exitCode === 0) {
                        win.renameDialogOpen = false;
                        renameName.text = "";
                    } else {
                        win.folderError = Tr.tr("Could not rename this item.");
                    }
                }
            }
            onVisibleChanged: {
                if (!visible) {
                    root.currentWindow = null;
                    destroy();
                }
            }

            Column {
                anchors.fill: parent
                spacing: 0

                Item {
                    width: parent.width
                    height: 58
                    StyledRect {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.leftMargin: Tokens.padding.medium
                        anchors.topMargin: Tokens.padding.medium
                        width: 42
                        height: 42
                        radius: Tokens.rounding.medium
                        color: Colours.tPalette.m3surfaceContainerHigh
                        StateLayer {
                            disabled: win.currentPath === root.homePath
                            onClicked: win.currentPath = root.parentPath(win.currentPath)
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "arrow_upward"
                            color: Colours.palette.m3onSurface
                        }
                    }

                    StyledRect {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: Tokens.padding.medium
                        anchors.topMargin: Tokens.padding.medium
                        width: 42
                        height: 42
                        radius: Tokens.rounding.medium
                        color: Colours.palette.m3primary
                        StateLayer {
                            onClicked: {
                                win.folderError = "";
                                folderName.text = "";
                                win.folderDialogOpen = true;
                                Qt.callLater(() => folderName.forceActiveFocus());
                            }
                        }
                        MaterialIcon {
                            anchors.centerIn: parent
                            text: "create_new_folder"
                            color: Colours.palette.m3onPrimary
                        }
                    }

                    StyledRect {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: Tokens.padding.medium + 42 + Tokens.spacing.small
                        anchors.rightMargin: Tokens.padding.medium * 2 + 42
                        anchors.topMargin: Tokens.padding.medium
                        height: 42
                        radius: Tokens.rounding.medium
                        color: Colours.tPalette.m3surfaceContainerHigh
                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: Tokens.padding.large
                            anchors.rightMargin: Tokens.padding.large
                            verticalAlignment: Text.AlignVCenter
                            text: win.currentPath
                            elide: Text.ElideLeft
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: parent.height - 58
                    spacing: 0

                    StyledRect {
                        width: 190
                        height: parent.height
                        color: Colours.tPalette.m3surfaceContainer
                        Column {
                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            spacing: Tokens.spacing.extraSmall
                            Repeater {
                                model: [
                                    {
                                        name: "Home",
                                        icon: "home",
                                        path: root.homePath
                                    },
                                    {
                                        name: "Desktop",
                                        icon: "desktop_windows",
                                        path: root.homePath + "/Desktop"
                                    },
                                    {
                                        name: "Documents",
                                        icon: "description",
                                        path: root.homePath + "/Documents"
                                    },
                                    {
                                        name: "Downloads",
                                        icon: "download",
                                        path: root.homePath + "/Downloads"
                                    },
                                    {
                                        name: "Pictures",
                                        icon: "image",
                                        path: root.homePath + "/Pictures"
                                    },
                                    {
                                        name: "Music",
                                        icon: "music_note",
                                        path: root.homePath + "/Music"
                                    },
                                    {
                                        name: "Videos",
                                        icon: "video_library",
                                        path: root.homePath + "/Videos"
                                    }
                                ]
                                delegate: StyledRect {
                                    required property var modelData
                                    width: parent.width
                                    height: 42
                                    radius: Tokens.rounding.full
                                    color: win.currentPath === modelData.path ? Colours.palette.m3secondaryContainer : "transparent"
                                    StateLayer {
                                        onClicked: win.currentPath = modelData.path
                                    }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: Tokens.padding.medium
                                        anchors.rightMargin: Tokens.padding.medium
                                        spacing: Tokens.spacing.medium
                                        MaterialIcon {
                                            Layout.alignment: Qt.AlignVCenter
                                            text: modelData.icon
                                            color: win.currentPath === modelData.path ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
                                        }
                                        StyledText {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            text: Tr.tr(modelData.name)
                                            color: win.currentPath === modelData.path ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ListView {
                        id: entries
                        width: parent.width - 190
                        height: parent.height
                        clip: true
                        model: FileSystemModel {
                            id: fileModel
                            path: win.currentPath
                            showHidden: win.showHiddenFiles
                        }
                        spacing: Tokens.spacing.extraSmall
                        leftMargin: Tokens.padding.medium
                        rightMargin: Tokens.padding.medium
                        topMargin: Tokens.padding.medium
                        bottomMargin: Tokens.padding.medium

                        MouseArea {
                            anchors.fill: parent
                            z: 2
                            acceptedButtons: Qt.RightButton
                            onClicked: mouse => {
                                const item = entries.itemAt(mouse.x + entries.contentX, mouse.y + entries.contentY);
                                win.contextPath = item?.modelData?.path ?? "";
                                win.contextEntry = item?.modelData ?? null;
                                const point = mapToItem(win.contentItem, mouse.x, mouse.y);
                                win.contextX = point.x;
                                win.contextY = point.y;
                                win.contextOpen = true;
                            }
                        }

                        delegate: StyledRect {
                            required property FileSystemEntry modelData
                            visible: !!modelData
                            width: entries.width - entries.leftMargin - entries.rightMargin
                            height: 58
                            radius: Tokens.rounding.medium
                            color: Colours.tPalette.m3surfaceContainer
                            StateLayer {
                                onDoubleClicked: {
                                    if (!modelData)
                                        return;
                                    if (modelData.isDir)
                                        win.currentPath = modelData.path;
                                    else
                                        Quickshell.execDetached(["xdg-open", modelData.path]);
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.large
                                anchors.rightMargin: Tokens.padding.large
                                spacing: Tokens.spacing.medium
                                CachingIconImage {
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitSize: 38
                                    source: modelData?.isImage ? Qt.resolvedUrl(modelData.path) : Quickshell.iconPath(modelData?.isDir ? "folder" : (modelData?.mimeType?.replace("/", "-") ?? "application-x-generic"), "application-x-generic")
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: modelData?.name ?? ""
                                    color: Colours.palette.m3onSurface
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData?.isDir ? Tr.tr("Folder") : (modelData?.mimeType ?? "")
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.body.small
                                }
                            }
                        }
                    }
                }
            }

            StyledRect {
                id: contextMenu
                z: 500
                visible: win.contextOpen
                x: Math.max(Tokens.padding.small, Math.min(win.contextX, win.width - width - Tokens.padding.small))
                y: Math.max(Tokens.padding.small, Math.min(win.contextY, win.height - height - Tokens.padding.small))
                width: 220
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh
                implicitHeight: menuItems.implicitHeight + Tokens.padding.small * 2

                Column {
                    id: menuItems
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.small
                    spacing: Tokens.spacing.extraSmall

                    Repeater {
                        id: menuActions
                        model: [
                            {
                                label: Tr.tr("Open"),
                                icon: "open_in_new",
                                visible: !!win.contextEntry,
                                run: () => {
                                    if (win.contextEntry?.isDir)
                                        win.currentPath = win.contextEntry.path;
                                    else if (win.contextEntry)
                                        Quickshell.execDetached(["xdg-open", win.contextEntry.path]);
                                }
                            },
                            {
                                label: Tr.tr("Rename"),
                                icon: "edit",
                                visible: !!win.contextEntry,
                                run: () => {
                                    win.folderError = "";
                                    renameName.text = win.contextEntry?.name ?? "";
                                    win.renameDialogOpen = true;
                                    Qt.callLater(() => renameName.forceActiveFocus());
                                }
                            },
                            {
                                label: Tr.tr("Move to Trash"),
                                icon: "delete_outline",
                                visible: !!win.contextEntry,
                                run: () => {
                                    Quickshell.execDetached(["gio", "trash", win.contextEntry.path]);
                                }
                            },
                            {
                                label: Tr.tr("New folder"),
                                icon: "create_new_folder",
                                visible: true,
                                run: () => {
                                    win.folderError = "";
                                    folderName.text = "";
                                    win.folderDialogOpen = true;
                                    Qt.callLater(() => folderName.forceActiveFocus());
                                }
                            },
                            {
                                label: win.showHiddenFiles ? Tr.tr("Hide hidden files") : Tr.tr("Show hidden files"),
                                icon: win.showHiddenFiles ? "visibility_off" : "visibility",
                                visible: true,
                                run: () => win.showHiddenFiles = !win.showHiddenFiles
                            }
                        ]

                        delegate: StyledRect {
                            id: menuActionItem
                            required property var modelData
                            width: menuItems.width
                            height: modelData.visible ? 42 : 0
                            visible: modelData.visible
                            radius: Tokens.rounding.medium
                            color: "transparent"
                            StateLayer {
                                onClicked: {
                                    menuActionItem.modelData.run();
                                    win.contextOpen = false;
                                }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.padding.medium
                                anchors.rightMargin: Tokens.padding.medium
                                spacing: Tokens.spacing.medium
                                MaterialIcon {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: modelData.icon
                                    color: Colours.palette.m3onSurfaceVariant
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.fillWidth: true
                                    text: modelData.label
                                    color: Colours.palette.m3onSurface
                                }
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                z: 400
                visible: win.contextOpen || win.folderDialogOpen || win.renameDialogOpen
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: {
                    if (win.contextOpen && !contextMenu.contains(mapToItem(contextMenu, mouse.x, mouse.y)))
                        win.contextOpen = false;
                }
            }

            StyledRect {
                z: 600
                visible: win.folderDialogOpen
                anchors.centerIn: parent
                width: Math.min(420, win.width - Tokens.padding.extraLarge * 2)
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainerHigh
                implicitHeight: folderDialogColumn.implicitHeight + Tokens.padding.large * 2

                ColumnLayout {
                    id: folderDialogColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Create folder")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                    }
                    StyledTextField {
                        id: folderName
                        Layout.fillWidth: true
                        placeholderText: Tr.tr("Folder name")
                        onAccepted: win.createFolder()
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: win.folderError.length > 0
                        text: win.folderError
                        color: Colours.palette.m3error
                        font: Tokens.font.body.small
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.small
                        StyledRect {
                            implicitWidth: cancelText.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: cancelText.implicitHeight + Tokens.padding.medium * 2
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainer
                            StateLayer {
                                onClicked: win.folderDialogOpen = false
                            }
                            StyledText {
                                id: cancelText
                                anchors.centerIn: parent
                                text: Tr.tr("Cancel")
                                color: Colours.palette.m3onSurface
                            }
                        }
                        StyledRect {
                            implicitWidth: createText.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: createText.implicitHeight + Tokens.padding.medium * 2
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary
                            StateLayer {
                                disabled: createFolderProcess.running
                                onClicked: win.createFolder()
                            }
                            StyledText {
                                id: createText
                                anchors.centerIn: parent
                                text: Tr.tr("Create")
                                color: Colours.palette.m3onPrimary
                            }
                        }
                    }
                }
            }

            StyledRect {
                z: 600
                visible: win.renameDialogOpen
                anchors.centerIn: parent
                width: Math.min(420, win.width - Tokens.padding.extraLarge * 2)
                radius: Tokens.rounding.extraLarge
                color: Colours.tPalette.m3surfaceContainerHigh
                implicitHeight: renameDialogColumn.implicitHeight + Tokens.padding.large * 2

                ColumnLayout {
                    id: renameDialogColumn
                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: Tr.tr("Rename")
                        font: Tokens.font.title.medium
                        color: Colours.palette.m3onSurface
                    }
                    StyledTextField {
                        id: renameName
                        Layout.fillWidth: true
                        placeholderText: Tr.tr("Name")
                        onAccepted: {
                            win.renameEntry();
                        }
                    }
                    StyledText {
                        Layout.fillWidth: true
                        visible: win.folderError.length > 0
                        text: win.folderError
                        color: Colours.palette.m3error
                        font: Tokens.font.body.small
                    }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        spacing: Tokens.spacing.small
                        StyledRect {
                            implicitWidth: renameCancelText.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: renameCancelText.implicitHeight + Tokens.padding.medium * 2
                            radius: Tokens.rounding.full
                            color: Colours.tPalette.m3surfaceContainer
                            StateLayer {
                                onClicked: win.renameDialogOpen = false
                            }
                            StyledText {
                                id: renameCancelText
                                anchors.centerIn: parent
                                text: Tr.tr("Cancel")
                                color: Colours.palette.m3onSurface
                            }
                        }
                        StyledRect {
                            implicitWidth: renameCreateText.implicitWidth + Tokens.padding.large * 2
                            implicitHeight: renameCreateText.implicitHeight + Tokens.padding.medium * 2
                            radius: Tokens.rounding.full
                            color: Colours.palette.m3primary
                            StateLayer {
                                disabled: renameProcess.running
                                onClicked: win.renameEntry()
                            }
                            StyledText {
                                id: renameCreateText
                                anchors.centerIn: parent
                                text: Tr.tr("Rename")
                                color: Colours.palette.m3onPrimary
                            }
                        }
                    }
                }
            }
        }
    }

    function parentPath(path: string): string {
        const clean = path.replace(/\/$/, "");
        const slash = clean.lastIndexOf("/");
        return slash <= 0 ? "/" : clean.slice(0, slash);
    }
}
