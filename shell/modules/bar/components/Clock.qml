pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Caelestia.I18n
import Caelestia.Config
import qs.components
import qs.services
StyledRect {
    id: root
    readonly property color colour: Colours.palette.m3primary
    readonly property int padding: Config.bar.clock.background ? Tokens.padding.medium : Tokens.padding.extraSmall
    implicitWidth: layout.implicitWidth + padding * 2
    implicitHeight: Tokens.sizes.bar.innerWidth
    color: Qt.alpha(Colours.tPalette.m3surfaceContainer, Config.bar.clock.background ? Colours.tPalette.m3surfaceContainer.a : 0)
    radius: Tokens.rounding.full
    RowLayout {
        id: layout
        anchors.centerIn: parent
        spacing: Tokens.spacing.small
        MaterialIcon { visible: Config.bar.clock.showIcon; text: "calendar_month"; color: root.colour }
        StyledText {
            text: (root.Config.bar.clock.showDate ? Time.format("ddd d · ") : "") + Time.hourStr + ":" + Time.minuteStr + (root.Config.bar.clock.showSeconds ? Time.format(":ss") : "") + (Units.twelveHourClock ? " " + Time.amPmStr.toLowerCase() : "")
            font: Tokens.font.body.builders.small.scale(1.1).build()
            color: root.colour
        }
    }
}
