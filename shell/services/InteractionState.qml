pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../core"

InteractionModel {
    id: root
    function screenFor(window) {
        if (window && window.screen && Quickshell.screens.indexOf(window.screen)>=0) return window.screen
        const monitor=Hyprland.focusedMonitor
        return Quickshell.screens.find(output=>monitor && output.name===monitor.name) || Quickshell.screens[0] || null
    }
    property Connections screenWatcher: Connections {
        target:Quickshell
        function onScreensChanged() { if(root.owner && Quickshell.screens.indexOf(root.screen)<0)root.dismiss("screen-removed") }
    }
}
