pragma ComponentBehavior: Bound
import QtQuick
import Devine.Config
import Devine.I18n
import qs.components
import qs.components.images
import qs.services
import qs.utils
Item {
    id: root
    required property var bar
    required property Brightness.Monitor monitor
    property color colour: Colours.palette.m3primary
    readonly property string windowTitle: {
        const active = Hypr.activeToplevel;
        const title = active?.title || active?.lastIpcObject?.title;
        if (!title) return Tr.trCtx("Desktop", "shown when no window is focused");
        if (Config.bar.activeWindow.compact) {
            const parts = title.split(/\s+[-–—]\s+/);
            if (parts.length > 1) return parts[parts.length - 1].trim();
        }
        return title;
    }
    implicitWidth: Math.min(bar.width * 0.3, Math.ceil(icon.implicitWidth + Tokens.spacing.small + titleMetrics.advanceWidth) + 10)
    implicitHeight: Math.max(28, icon.implicitHeight, titleText.implicitHeight)
    TextMetrics { id: titleMetrics; text: root.windowTitle; font: titleText.font }
    CachingIconImage {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitSize: 24
        source: Icons.getAppIcon(Hypr.activeToplevel?.lastIpcObject.class ?? "", "application-x-executable")
    }
    StyledText {
        id: titleText
        anchors.left: icon.right
        anchors.leftMargin: Tokens.spacing.small
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.windowTitle
        font: Tokens.font.body.builders.small.letterSpacing(1.1).build()
        color: root.colour
        elide: Text.ElideRight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const p = root.bar.popouts;
            p.currentCenter = root.mapToItem(root.bar, root.width / 2, 0).x;
            p.currentName = "activewindow";
            p.hasCurrent = !p.hasCurrent;
        }
    }
}
