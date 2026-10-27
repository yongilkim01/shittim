pragma Singleton
import QtQuick
import Quickshell.Hyprland
import "../core"

WindowClient {
    id:root
    onFinished:WindowCatalog.refresh()
    Timer { id:reflow;interval:700;onTriggered:root.submit("reflow","active") }
    Component.onCompleted:reflow.restart()
    Connections {
        target:Hyprland
        function onRawEvent(event){if(["monitoradded","monitorremoved","configreloaded","fullscreen"].indexOf(event.name)>=0)reflow.restart()}
    }
}
