import QtQuick
import QtQuick.Shapes
import qs.services

Item {
    id: root

    readonly property real designWidth: 96
    readonly property real designHeight: 96

    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3onSurface

    implicitWidth: designWidth
    implicitHeight: designHeight

    Item {
        id: artwork
        width: root.designWidth
        height: root.designHeight
        anchors.centerIn: parent
        scale: Math.min(root.width / root.designWidth, root.height / root.designHeight)

        Text {
            anchors.centerIn: parent
            text: "D"
            color: root.bottomColour
            font.family: "sans-serif"
            font.pixelSize: 76
            font.weight: Font.DemiBold
            font.letterSpacing: -5
            y: 4
        }

        Shape {
            anchors.right: parent.right
            anchors.top: parent.top
            width: 28
            height: 28
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.topColour
                strokeColor: "transparent"
                startX: 14
                startY: 0
                PathLine { x: 17; y: 10 }
                PathLine { x: 28; y: 14 }
                PathLine { x: 17; y: 18 }
                PathLine { x: 14; y: 28 }
                PathLine { x: 10; y: 18 }
                PathLine { x: 0; y: 14 }
                PathLine { x: 10; y: 10 }
                PathLine { x: 14; y: 0 }
            }
        }
    }
}
