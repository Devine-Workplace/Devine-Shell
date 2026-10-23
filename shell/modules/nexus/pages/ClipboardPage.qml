pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Devine.Config
import Devine.I18n
import qs.components.controls
import qs.modules.nexus.common
import qs.services

PageBase {
    id: root

    title: Tr.tr("Clipboard")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Clipboard history")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Show image previews")
            subtext: Tr.tr("Display copied images in clipboard history")
            checked: ClipboardSettings.showImagePreviews
            onToggled: ClipboardSettings.showImagePreviews = checked
        }

        SectionHeader {
            text: Tr.tr("Popup position")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true
                text: Tr.tr("Left side")
                isToggle: true
                checked: ClipboardSettings.popupSide === "left"
                onClicked: ClipboardSettings.popupSide = "left"
            }

            TextButton {
                Layout.fillWidth: true
                text: Tr.tr("Right side")
                isToggle: true
                checked: ClipboardSettings.popupSide === "right"
                onClicked: ClipboardSettings.popupSide = "right"
            }
        }
    }
}
