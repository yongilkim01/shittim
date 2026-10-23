import QtQuick
import Quickshell
import Quickshell.Wayland
import "../ui"
import "../services"
import "./control"
import "./notifications"

PanelWindow {
    id: window
    screen: NotificationState.popupScreen
    visible: screen !== null && NotificationState.model.popups.length > 0 && !NotificationState.opened && !ControlState.opened && !LauncherState.opened && !DashboardState.opened
    anchors { top: true; right: true }
    margins.top: Math.min(Theme.barHeight + Theme.spaceS, Math.max(0, (screen ? screen.height : 0) - 64))
    margins.right: Theme.spaceS
    implicitWidth: Math.max(1, Math.min(Theme.notificationWidth, (screen ? screen.width : 0) - Theme.spaceS * 2))
    readonly property real rowHeight: Math.max(1, Math.min(64, ((screen ? screen.height : 0) - margins.top - Theme.spaceS - 12) / Math.max(1, NotificationState.model.popups.length)))
    implicitHeight: Math.max(1, stack.implicitHeight)
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-notification-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    Column {
        id: stack; width: parent.width; spacing: 6
        Repeater {
            model: NotificationState.model.popups
            ControlFrame {
                required property var modelData
                width: stack.width; height: window.rowHeight; cut: 4
                strokeColor: modelData.urgency === 2 ? Theme.warning : Theme.accentDim
                fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
                NotificationRow {
                    width: Theme.notificationWidth; height: 50
                    anchors.centerIn: parent; scale: Math.min(1, parent.width / width, parent.height / height)
                    entry: parent.modelData; popup: true
                    onDismissed: NotificationState.model.dismissPopup(entry.id)
                    onActivated: {
                        if (entry.actions.some(action => action.id === "default")) NotificationState.invoke(entry.id, "default")
                        else NotificationState.showDetail(entry.id)
                    }
                }
            }
        }
    }
}
