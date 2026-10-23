import QtQuick
import Quickshell
import Devine.Config
import qs.components
import qs.services
import qs.modules.bar as Bar
import qs.modules.dashboard as Dashboard
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias dashboard: dashboard
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar
    readonly property alias capsLockIndicator: capsLockIndicator

    anchors.fill: parent
    anchors.margins: borderThickness
    anchors.leftMargin: borderThickness
    anchors.bottomMargin: bar.implicitHeight

    Item {
        id: capsLockIndicator

        property real offsetScale: 1
        property bool displayCapsLock: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        // Retract the complete surface so its rounded lower edge cannot leave
        // a small notch visible along the top of the screen.
        anchors.topMargin: -implicitHeight * offsetScale
        width: implicitWidth
        height: implicitHeight
        implicitWidth: contentRow.implicitWidth + Tokens.padding.largeIncreased * 2
        implicitHeight: contentRow.implicitHeight + Tokens.padding.small * 2
        opacity: 1 - offsetScale
        visible: offsetScale < 1

        Behavior on offsetScale {
            Anim {}
        }

        Row {
            id: contentRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.small

            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "keyboard_capslock"
                color: Colours.palette.m3onSurface
                fontStyle: Tokens.font.icon.medium
                fill: 1
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: capsLockIndicator.displayCapsLock ? "Caps Lock enabled" : "Caps Lock disabled"
                color: Colours.palette.m3onSurface
                font: Tokens.font.body.small
            }
        }

        function show(enabled: bool): void {
            displayCapsLock = enabled;
            offsetScale = 0;
            hideTimer.restart();
        }

        Connections {
            target: Hypr
            function onCapsLockChanged(): void {
                capsLockIndicator.show(Hypr.capsLock);
            }
        }

        Timer {
            id: hideTimer

            interval: 1400
            onTriggered: capsLockIndicator.offsetScale = 1
        }
    }

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            screenState: root.screenState
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        screenState: root.screenState
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper
        utilitiesPanel: utilities

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            screenState: root.screenState
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        screenState: root.screenState
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
    }

    Dashboard.Wrapper {
        id: dashboard

        screenState: root.screenState

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
        barHeight: root.bar.implicitHeight
    }

    Utilities.Wrapper {
        id: utilities

        screenState: root.screenState
        sidebar: sidebar
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.medium
    }

    Sidebar.Wrapper {
        id: sidebar

        screenState: root.screenState

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
        anchors.topMargin: -notifications.anchors.topMargin
    }
}
