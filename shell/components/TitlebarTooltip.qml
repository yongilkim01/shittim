import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../ui"
import "./windows"

PanelWindow {
    id: window
    TitlebarTipModel { id: tip }
    readonly property var monitor: Hyprland.monitors.values.find(candidate=>candidate.id===tip.monitorId) || null
    screen: monitor ? Quickshell.screens.find(candidate=>candidate.name===monitor.name) || null : null
    visible: screen!==null && tip.opened
    implicitWidth: Math.max(40,Math.min(160,label.implicitWidth+14))
    implicitHeight: 24
    readonly property point placement: tip.position(screen ? screen.width : 0,screen ? screen.height : 0,implicitWidth,implicitHeight)
    anchors { top:true;left:true }
    margins.left: placement.x; margins.top: placement.y
    color: Theme.transparent; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "shittim-titlebar-tooltip"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}
    Timer { id: delay;interval:650;onTriggered:tip.reveal() }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if(event.name==="shittim_titlebar_hover") {
                if(tip.accept(event.data))delay.restart()
                else if(!tip.active)delay.stop()
            } else if(event.name==="closewindow" && String(event.data).replace(/^0x/,"").toLowerCase()===tip.owner)tip.clear()
            else if(event.name==="configreloaded")tip.clear()
        }
    }
    Connections { target:Quickshell;function onScreensChanged(){tip.clear();delay.stop()} }
    Rectangle { anchors.fill:parent;color:Theme.floatingSurface;border.color:Theme.accentDim;border.width:1;radius:1 }
    HudText { id:label;anchors.fill:parent;anchors.margins:5;text:tip.label;font.pixelSize:10;horizontalAlignment:Text.AlignHCenter }
}
