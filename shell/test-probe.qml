//@ pragma AppId org.shittim.FocusProbe
//@ pragma ShellId shittim-focus-probe
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io

// A real Wayland toplevel; no test calls change its keyboard focus.
ShellRoot {
    id:root
    property int keys:0
    FloatingWindow {
        id:window;visible:Quickshell.env("SHITTIM_TEST_SESSION")==="1"
        title:"Shittim input probe";implicitWidth:420;implicitHeight:260;color:"#020f15"
        TextInput {id:input;anchors.fill:parent;focus:true;color:"#d5f8ff";font.pixelSize:18;onTextEdited:root.keys++}
    }
    IpcHandler {
        target:"probe"
        function status():string{return JSON.stringify({keys:root.keys,active:input.Window.active})}
    }
}
