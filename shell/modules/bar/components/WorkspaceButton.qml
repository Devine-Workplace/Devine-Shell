pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Devine.Config
import qs.components
import qs.services
import qs.utils

Rectangle {
    id: root
    objectName: "taskbarWorkspaces"
    required property var bar
    required property ShellScreen screen
    required property var popouts
    readonly property var monitor: Hypr.monitorFor(screen)
    readonly property var desktops: Hypr.workspaces.values.filter(w => !w.name.startsWith("special:") && w.monitor?.name === screen.name)
    readonly property var current: monitor?.activeWorkspace
    property var names: ({})
    readonly property string desktopLabel: names[String(current?.id)] ?? (current?.id > 0 ? "Desktop " + current.id : (current?.name ?? "Desktop").replace("special:", ""))
    implicitWidth: Math.min(170, label.implicitWidth + 62)
    implicitHeight: 32
    radius: 16
    color: Colours.palette.m3surfaceContainerHigh
    function showMenu(): void {
        // The native popout morph starts at the bar's lower edge. Keep this
        // anchor on that same edge so it grows directly out of this button.
        popouts.currentCenter = root.mapToItem(bar, width / 2, height).x;
        popouts.currentName = "workspaces";
        popouts.hasCurrent = true;
        bar.popoutHit = true;
    }
    FileView {
        path: Paths.config + "/workspace-names.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.names = JSON.parse(text()); } catch(e) {} }
    }
    MaterialIcon {
        x: 10; anchors.verticalCenter: parent.verticalCenter
        text: "desktop_windows"
        color: Colours.palette.m3primary
        fontStyle: Tokens.font.icon.small
    }
    StyledText {
        id: label
        x: 34; anchors.verticalCenter: parent.verticalCenter
        width: Math.min(108, implicitWidth)
        text: root.desktopLabel
        color: Colours.palette.m3onSurface
        elide: Text.ElideRight
        font: Tokens.font.body.small
    }
    StyledText {
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        text: String(root.desktops.length)
        color: Colours.palette.m3onSurfaceVariant
        font.pixelSize: 11
    }
    HoverHandler { onHoveredChanged: if (hovered) root.showMenu() }
    MouseArea { anchors.fill: parent; onClicked: root.showMenu() }
}
