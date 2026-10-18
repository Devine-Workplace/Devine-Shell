pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.dashboard.dash as Dash
Item {
    implicitWidth: 360
    implicitHeight: calendar.implicitHeight
    Dash.Calendar {
        id: calendar
        screenState: ShellState.forScreen(QsWindow.window.screen)
    }
}
