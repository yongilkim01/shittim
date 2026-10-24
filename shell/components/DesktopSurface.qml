import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../ui"
import "./desktop"

PanelWindow {
    id:window
    required property var modelData
    screen:modelData
    anchors { top:true; bottom:true; left:true; right:true }
    color:Theme.background; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"shittim-desktop"
    WlrLayershell.layer:WlrLayer.Background
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.OnDemand
    Image { anchors.fill:parent; source:Qt.resolvedUrl("../../assets/wallpapers/shittim-lake.png"); fillMode:Image.PreserveAspectCrop; asynchronous:true }
    DesktopView {
        anchors.fill:parent; anchors.topMargin:Theme.barHeight+Theme.spaceM; anchors.bottomMargin:Theme.dockHeight+Theme.spaceXL; anchors.leftMargin:Theme.spaceM; anchors.rightMargin:Theme.spaceM
        entries:DesktopState.entries; saved:DesktopState.positions[window.screen.name] || {}; error:DesktopState.error; busy:DesktopState.busy
        iconSource:LauncherState.iconSource
        onRequested:(operation,values)=>DesktopState.send(operation,values)
        onPositionsSaved:values=>DesktopState.save(window.screen.name,values)
        onRefreshRequested:DesktopState.refresh()
    }
}
