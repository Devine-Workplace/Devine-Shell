import QtQuick
import Devine.Config
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: Math.round(Tokens.font.body.large.pointSize * 1.2)
    implicitHeight: Math.round(Tokens.font.body.large.pointSize * 1.2)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const screenState = ShellState.forActive();
            screenState.launcher = !screenState.launcher;
        }
    }

    Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        source: SysInfo.osLogo
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        mipmap: true
    }

    MaterialIcon {
        anchors.centerIn: parent
        visible: !SysInfo.osLogo
        text: "computer"
        color: Colours.palette.m3onSurface
        fontStyle: Tokens.font.icon.small
    }
}
