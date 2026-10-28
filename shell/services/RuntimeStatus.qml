pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id:root
    readonly property string contract:"interaction-window-v1"
    property string fingerprint:""
    Process {
        running:true;command:["python3",Quickshell.shellDir+"/../scripts/runtime-status.py","--fingerprint"]
        stdout:StdioCollector {onStreamFinished:root.fingerprint=text.trim()}
    }
    IpcHandler {
        target:"runtime"
        function status():string {
            return JSON.stringify({protocol:1,contract:root.contract,fingerprint:root.fingerprint,pid:Quickshell.processId,
                configRoot:Quickshell.shellDir,owner:InteractionState.owner ? InteractionState.owner.name : "",
                generation:InteractionState.generation,windowBusy:WindowCommands.busy,
                windowRequests:Object.keys(WindowCommands.requests).length,launcherReady:LauncherState.ready,
                screens:Quickshell.screens.map(output=>output.name),ownerScreen:InteractionState.screen ? InteractionState.screen.name : "",
                control:{opened:ControlState.opened,page:ControlState.page,
                    anchorScreen:ControlState.anchorWindow && ControlState.anchorWindow.screen ? ControlState.anchorWindow.screen.name : ""}})
        }
    }
}
