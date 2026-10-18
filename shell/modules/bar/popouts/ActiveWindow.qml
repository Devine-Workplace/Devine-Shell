import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root
    required property PopoutState popouts
    implicitWidth: Hypr.activeToplevel ? child.implicitWidth : -Tokens.padding.extraLargeIncreased
    implicitHeight: child.implicitHeight

    Column {
        id: child
        anchors.centerIn: parent
        spacing: Tokens.spacing.medium

        StyledRect {
            id: header
            implicitWidth: Math.max(280, previewFrame.implicitWidth)
            implicitHeight: detailsRow.implicitHeight + Tokens.padding.small * 2
            color: Colours.tPalette.m3surfaceContainer
            radius: Tokens.rounding.large

            RowLayout {
                id: detailsRow
                anchors.fill: parent
                anchors.margins: Tokens.padding.small
                spacing: Tokens.spacing.medium

                CachingIconImage {
                    Layout.alignment: Qt.AlignVCenter
                    implicitSize: 32
                    source: Icons.getAppIcon(Hypr.activeToplevel?.lastIpcObject.class ?? "", "image-missing")
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    StyledText {
                        Layout.fillWidth: true
                        text: Hypr.activeToplevel?.title ?? ""
                        color: Colours.palette.m3primary
                        font: Tokens.font.body.medium
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Hypr.activeToplevel?.lastIpcObject.class ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                Item {
                    implicitWidth: 32
                    implicitHeight: 32
                    Layout.alignment: Qt.AlignVCenter
                    StateLayer {
                        radius: Tokens.rounding.large
                        onClicked: root.popouts.detachRequested("winfo")
                    }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "open_in_full"
                        color: Colours.palette.m3primary
                        fontStyle: Tokens.font.icon.small
                    }
                }
            }
        }

        ClippingWrapperRectangle {
            id: previewFrame
            color: Colours.tPalette.m3surfaceContainer
            border.color: Colours.palette.m3outlineVariant
            border.width: 1
            radius: Tokens.rounding.large
            ScreencopyView {
                captureSource: Hypr.activeToplevel?.wayland ?? null
                live: visible
                constraintSize.width: Tokens.sizes.bar.windowPreviewSize
                constraintSize.height: Tokens.sizes.bar.windowPreviewSize
            }
        }
    }
}
