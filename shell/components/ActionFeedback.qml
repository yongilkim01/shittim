import QtQuick
import Quickshell
import Quickshell.Wayland
import "../ui"
import "../services"

// Action errors stay visible after a menu closes and never take input from an app.
PanelWindow {
    id:window
    property string message:""
    function report(text){if(!text)return;screen=InteractionState.screenFor(null);message=text;expiry.restart()}
    visible:message.length>0 && screen!==null
    anchors {top:true;right:true}
    margins.top:Theme.barHeight+Theme.spaceS;margins.right:Theme.spaceS
    implicitWidth:Math.max(1,Math.min(400,(screen ? screen.width : 0)-16));implicitHeight:Math.max(48,label.implicitHeight+24)
    exclusionMode:ExclusionMode.Ignore;color:Theme.transparent;mask:Region {}
    WlrLayershell.namespace:"shittim-action-feedback";WlrLayershell.layer:WlrLayer.Overlay
    WlrLayershell.keyboardFocus:WlrKeyboardFocus.None
    HudPanel {anchors.fill:parent;active:true}
    HudText {id:label;x:12;y:12;width:parent.width-24;text:window.message;wrapMode:Text.Wrap;color:Theme.warning}
    Timer {id:expiry;interval:6500;onTriggered:window.message=""}
    Connections {target:WindowCommands;function onErrorChanged(){window.report(WindowCommands.error)}}
    Connections {target:CaptureState;function onErrorChanged(){window.report(CaptureState.error)}}
}
