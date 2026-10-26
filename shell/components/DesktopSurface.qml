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
    function releaseInput(handoff) { inputActive=false;if(view)view.releaseFocus(Boolean(handoff)) }
    Component.onCompleted: DesktopState.registerInput(trace)
    Component.onDestruction: DesktopState.unregisterInput(trace)
    screen:modelData
    anchors { top:true; bottom:true; left:true; right:true }
    color:Theme.background; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"shittim-desktop"
    WlrLayershell.layer:WlrLayer.Background
    WlrLayershell.keyboardFocus:inputActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    DesktopInputTrace {
        id:trace
        enabled:DesktopState.tracingInput
        requested:window.inputActive
        grabbed:inputGrab.active
        windowActive:view.Window.active
        viewFocused:view.activeFocus
    }
    HyprlandFocusGrab { id:inputGrab;active:window.visible && window.inputActive;windows:[window];onCleared:{trace.record("grab-cleared");window.releaseInput(true)} }
    Connections { target:Hyprland;function onActiveToplevelChanged(){trace.record("active-window");if(window.inputActive)window.releaseInput(true)} }
    Image { anchors.fill:parent; source:LauncherState.assetSource("wallpapers/shittim-lake.png"); fillMode:Image.PreserveAspectCrop; asynchronous:true }
    DesktopView {
        id:view
        anchors.fill:parent; anchors.topMargin:Theme.barHeight+Theme.spaceM; anchors.bottomMargin:Theme.dockHeight+Theme.spaceXL; anchors.leftMargin:Theme.spaceM; anchors.rightMargin:Theme.spaceM
        entries:DesktopState.entries; saved:DesktopState.positions[window.screen.name] || {}; error:DesktopState.error; busy:DesktopState.busy
        iconSource:LauncherState.iconSource
        onFocusRequested:{trace.record("desktop-press");window.inputActive=true}
        onFocusRejected:trace.record("press-ignored")
        onRequested:(operation,values)=>{if(operation==="open" || operation==="open-desktop")window.releaseInput();DesktopState.send(operation,values)}
        onPositionsSaved:values=>DesktopState.save(window.screen.name,values)
        onRefreshRequested:DesktopState.refresh()
    }
}
