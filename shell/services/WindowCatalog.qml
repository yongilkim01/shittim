pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core/WindowData.js" as Data

Scope {
    id:root
    property var recent:[]
    readonly property var windows:Hyprland.toplevels.values.map(Data.normalize).filter(window=>/^[0-9a-fA-F]+$/.test(window.address))
    function refresh(){Hyprland.refreshToplevels()}
    Component.onCompleted:{if(Hyprland.activeToplevel)recent=[Hyprland.activeToplevel.address];refresh()}
    Timer { id:refreshTimer;interval:60;onTriggered:root.refresh() }
    Connections {
        target:Hyprland
        function onActiveToplevelChanged(){const window=Hyprland.activeToplevel;if(window)root.recent=[window.address].concat(root.recent.filter(address=>address!==window.address)).slice(0,512)}
        function onRawEvent(event){
            if(["openwindow","closewindow","movewindow","movewindowv2","changefloatingmode","fullscreen","monitoradded","monitorremoved"].indexOf(event.name)>=0
                || (event.name==="custom" && event.data.indexOf("shittim-window-state,")===0))refreshTimer.restart()
        }
    }
}
