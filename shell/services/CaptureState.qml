pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/ActionErrors.js" as Errors

Scope {
    id:root
    readonly property bool screenshotAvailable:SystemBackend.state.screenshotAvailable===true
    readonly property bool busy:ledger.busy
    property string error:""
    property int request:0
    signal starting()
    function retain(consumer){SystemBackend.retain(consumer)}
    function release(consumer){SystemBackend.release(consumer)}
    function takeScreenshot(){if(!screenshotAvailable || busy)return;error="";request=ledger.begin("screenshot",15000,"");starting();process.running=true}
    RequestLedger {id:ledger;onFinished:result=>{if(!result.ok)root.error=Errors.message(result.code);if(result.status==="timeout"){process.running=false;killTimer.restart()}}}
    Timer {id:killTimer;interval:1000;onTriggered:if(process.running)process.signal(9)}
    Process {
        id:process;command:["python3","-u",Quickshell.shellDir+"/../scripts/control-service.py","--screenshot"]
        onExited:(code,status)=>{killTimer.stop();ledger.complete(root.request,code===0,code===2 ? "ClipboardCopyFailed" : "ScreenshotFailed",false)}
    }
}
