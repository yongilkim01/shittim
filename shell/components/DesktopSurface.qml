import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../ui"
import "./desktop"
import "../core"

PanelWindow {
    id:window
    required property var modelData
    readonly property bool inputActive:desktopSession.active
    function releaseInput(handoff) { desktopSession.close(handoff ? "outside" : "action") }
    PanelSession {
        id:desktopSession;coordinator:InteractionState;name:"desktop";kind:"desktop"
        onRevoked:reason=>{if(reason==="outside")trace.record("grab-cleared");view.releaseFocus(reason!=="action")}
    }
    Component.onCompleted: DesktopState.registerInput(trace)
    Component.onDestruction: DesktopState.unregisterInput(trace)
    screen:modelData
    anchors { top:true; bottom:true; left:true; right:true }
    color:Theme.background; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"shittim-desktop"
    WlrLayershell.layer:WlrLayer.Background
    WlrLayershell.keyboardFocus:inputGrab.keyboardFocus
    DesktopInputTrace {
        id:trace
        enabled:DesktopState.tracingInput
        requested:window.inputActive
        grabbed:inputGrab.active
        windowActive:view.Window.active
        viewFocused:view.activeFocus
    }
    PanelInput { id:inputGrab;window:window;session:desktopSession }
    Connections { target:Hyprland;function onActiveToplevelChanged(){trace.record("active-window");if(window.inputActive)window.releaseInput(true)} }
    Image { anchors.fill:parent; source:LauncherState.assetSource("wallpapers/shittim-lake.png"); fillMode:Image.PreserveAspectCrop; asynchronous:true }
    DesktopView {
        id:view
        anchors.fill:parent; anchors.topMargin:Theme.barHeight+Theme.spaceM; anchors.bottomMargin:Theme.dockHeight+Theme.spaceXL; anchors.leftMargin:Theme.spaceM; anchors.rightMargin:Theme.spaceM
        entries:DesktopState.entries; saved:DesktopState.positions[window.screen.name] || {}; error:DesktopState.error; busy:DesktopState.busy
        iconSource:LauncherState.iconSource
        onFocusRequested:{trace.record("desktop-press");desktopSession.open(window.screen)}
        onFocusRejected:trace.record("press-ignored")
        onRequested:(operation,values)=>{if(operation==="open" || operation==="open-desktop")window.releaseInput();DesktopState.send(operation,values)}
        onPositionsSaved:values=>DesktopState.save(window.screen.name,values)
        onRefreshRequested:DesktopState.refresh()
    }
}
