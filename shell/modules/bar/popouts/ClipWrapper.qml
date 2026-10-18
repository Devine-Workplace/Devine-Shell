pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

StyledClippingRect {
    id: root

    radius: content.currentName === "workspaces" ? Math.min(Tokens.rounding.extraLarge, height / 2) : 0

    required property ShellScreen screen
    required property real borderThickness
    required property real barHeight

    readonly property bool pointerHovered: pointerHover.hovered
    HoverHandler { id: pointerHover; blocking: false }
    readonly property alias content: content
    readonly property real revealProgress: Math.max(0, Math.min(1, 1 - offsetScale))
    property real offsetScale: 1
    Timer {
        id: reveal
        interval: 16
        onTriggered: root.offsetScale = content.isDetached || content.hasCurrent ? 0 : 1
    }
    Connections {
        target: content
        function onHasCurrentChanged() {
            if (content.hasCurrent && root.offsetScale >= 1) reveal.restart();
            else { reveal.stop(); root.offsetScale = content.hasCurrent || content.isDetached ? 0 : 1; }
        }
        function onIsDetachedChanged() { reveal.restart(); }
    }

    visible: width > 0 && height > 0
    clip: true

    implicitWidth: content.implicitWidth
    readonly property real barExtension: content.currentName === "workspaces" && content.workspacePreviewExpanded && !content.isDetached ? barHeight * revealProgress : 0
    implicitHeight: content.implicitHeight * revealProgress + barExtension

    readonly property real anchorWidth: content.currentName === "workspaces" && content.workspaceBaseWidth > 0 ? content.workspaceBaseWidth : width
    x: content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : Math.max(0, Math.min(parent.width - width, content.currentCenter - borderThickness - anchorWidth / 2))
    y: {
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        return parent.height - height + barExtension;
    }

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on x {
        enabled: content.isDetached
        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: content.isDetached

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        barHeight: root.barHeight
        offsetScale: Math.max(0, Math.min(1, root.offsetScale))

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: (-implicitHeight - 5) * content.offsetScale + root.barExtension
    }
}
