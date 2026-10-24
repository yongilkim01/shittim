import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"
import "../ui"
import "./control"

PanelWindow {
    screen:SnapState.targetScreen
    visible:screen!==null && (SnapState.geometry!==null || SnapState.error.length>0)
    anchors { left:true;right:true;top:true;bottom:true }
    color:Theme.transparent; exclusionMode:ExclusionMode.Ignore
    WlrLayershell.namespace:"shittim-snap-preview"
    WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    mask:Region {}
    ControlFrame {
        visible:SnapState.geometry!==null
        x:SnapState.geometry ? SnapState.geometry[0] : 0; y:SnapState.geometry ? SnapState.geometry[1] : 0
        width:SnapState.geometry ? SnapState.geometry[2] : 0; height:SnapState.geometry ? SnapState.geometry[3] : 0
        fillColor:Theme.selectionFill; strokeColor:Theme.accent; cut:10
    }
    HudText { anchors.centerIn:parent; width:Math.min(500,parent.width); height:40; text:SnapState.error; color:Theme.danger; horizontalAlignment:Text.AlignHCenter }
}
