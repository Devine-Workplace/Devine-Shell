import QtQuick.Layouts
import Devine.Config
import Devine.I18n
import qs.components
import qs.services

ColumnLayout {
    spacing: Tokens.spacing.small

    StyledText {
        text: Hypr.capsLock ? Tr.tr("Caps lock enabled") : Tr.tr("Caps lock disabled")
    }

    StyledText {
        text: Hypr.numLock ? Tr.tr("Num lock enabled") : Tr.tr("Num lock disabled")
    }
}
