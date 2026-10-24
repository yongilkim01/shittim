import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "../services"
import "./windows"

PanelWindow {
    id: window
    screen: WindowState.targetScreen
    visible: WindowState.opened && screen !== null
    implicitWidth: Math.max(1, Math.min(680, (screen ? screen.width : 0) - 24))
    implicitHeight: Math.max(1, Math.min(420, (screen ? screen.height : 0) - Theme.barHeight - 24))
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-windows"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    HyprlandFocusGrab { active: window.visible; windows: [window]; onCleared: WindowState.close() }
    onVisibleChanged: if (visible) Qt.callLater(() => view.forceActiveFocus())
    WindowView {
        id: view; anchors.fill: parent; model: WindowState.model; error: WindowState.error; cycling: WindowState.cycling
        onRequested: (operation, address) => WindowState.perform(operation, address)
        onCloseRequested: WindowState.close()
        onCommitRequested: WindowState.commit()
    }
}
