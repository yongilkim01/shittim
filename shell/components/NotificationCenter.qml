import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./notifications"

PanelWindow {
    id: window
    screen: NotificationState.targetScreen
    visible: NotificationState.opened && NotificationState.targetScreen !== null
    anchors { top: true; right: true }
    margins.top: Math.min(Theme.barHeight + Theme.spaceS, Math.max(0, (screen ? screen.height : 0) - 80))
    margins.right: Theme.spaceS
    implicitWidth: Math.max(1, Math.min(Theme.notificationWidth, (screen ? screen.width : 0) - Theme.spaceS * 2))
    implicitHeight: Math.max(1, Math.min(Theme.notificationHeight, (screen ? screen.height : 0) - margins.top - Theme.spaceS))
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus:input.keyboardFocus
    PanelInput { id:input;window:window;session:NotificationState.panelSession }
    onVisibleChanged: if (visible) { content.expandedId = NotificationState.detailId; Qt.callLater(() => content.forceActiveFocus()) }
    NotificationView {
        id: content; anchors.fill: parent; model: NotificationState.model; active: window.visible
        ownership: NotificationState.ownership; ownerPid: NotificationState.ownerPid
        onCloseRequested: NotificationState.close()
        onDndRequested: NotificationState.toggleDnd()
        onActionRequested: (id, actionId) => NotificationState.invoke(id, actionId)
    }
}
