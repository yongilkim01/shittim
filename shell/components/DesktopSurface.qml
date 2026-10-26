import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../ui"
import "./desktop"

PanelWindow {
    id:window
    required property var modelData
    property bool inputActive: false
    function releaseInput() { inputActive=false;if(view)view.releaseFocus() }
    screen:modelData
    anchors { top:true; bottom:true; left:true; right:true }
    color:Theme.background; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"shittim-desktop"
    WlrLayershell.layer:WlrLayer.Background
    WlrLayershell.keyboardFocus:inputActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    HyprlandFocusGrab { active:window.visible && window.inputActive;windows:[window];onCleared:window.releaseInput() }
    Connections { target:Hyprland;function onActiveToplevelChanged(){if(window.inputActive)window.releaseInput()} }
    Image { anchors.fill:parent; source:LauncherState.assetSource("wallpapers/shittim-lake.png"); fillMode:Image.PreserveAspectCrop; asynchronous:true }
    DesktopView {
        id:view
        anchors.fill:parent; anchors.topMargin:Theme.barHeight+Theme.spaceM; anchors.bottomMargin:Theme.dockHeight+Theme.spaceXL; anchors.leftMargin:Theme.spaceM; anchors.rightMargin:Theme.spaceM
        entries:DesktopState.entries; saved:DesktopState.positions[window.screen.name] || {}; error:DesktopState.error; busy:DesktopState.busy
        iconSource:LauncherState.iconSource
        onFocusRequested:window.inputActive=true
        onRequested:(operation,values)=>{if(operation==="open" || operation==="open-desktop")window.releaseInput();DesktopState.send(operation,values)}
        onPositionsSaved:values=>DesktopState.save(window.screen.name,values)
        onRefreshRequested:DesktopState.refresh()
    }
}
