pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/ActionErrors.js" as Errors

// Transport and process lifetime only. Domain services own hardware/UI policies.
Scope {
    id:root
    readonly property string helperPath:Quickshell.shellDir+"/../scripts/control-service.py"
    property bool ready:false
    property var state:({})
    property string error:""
    property var prompt:null
    readonly property var pending:ledger.entries
    readonly property bool busy:ledger.busy
    readonly property bool wanted:consumers.active || busy || prompt!==null
    signal completed(var result)
    ConsumerSet { id:consumers }
    function retain(consumer){consumers.retain(consumer)}
    function release(consumer){consumers.release(consumer)}
    function sync(){if(wanted && !bridge.running){error="";ready=false;startup.restart();bridge.running=true}else if(!wanted && bridge.running)bridge.running=false}
    onWantedChanged:Qt.callLater(sync)
    function refresh(){if(!bridge.running){sync();return}if(ready)send({action:"refresh"})}
    function send(message, timeout) {
        if(!ready || !bridge.running){error=Errors.message("BackendUnavailable");return 0}
        const id=ledger.begin(message.action,timeout || 15000,message.device || "")
        if(!id){error=Errors.message("QueueFull");return 0}
        error="";bridge.write(JSON.stringify(Object.assign({},message,{id:id}))+"\n");return id
    }
    function answer(accept,value) {
        if(!prompt || !ready)return
        bridge.write(JSON.stringify({action:"reply",request:prompt.request,accept:accept,value:value})+"\n")
        prompt=null;challengeExpiry.stop()
    }
    function receive(message) {
        if(message.event==="ready"){ready=true;startup.stop();return}
        if(message.event==="state"){state=message;return}
        if(message.event==="prompt"){prompt=message;challengeExpiry.restart();return}
        if(message.event==="prompt-clear"){prompt=null;challengeExpiry.stop();return}
        if(message.event==="notice"){error=Errors.message(message.error);return}
        if(message.event==="result")ledger.complete(message.id,message.ok,message.error,false)
    }
    RequestLedger {
        id:ledger
        onFinished:result=>{
            if(result.status==="timeout")root.error=Errors.message(result.code)
            root.completed(result)
        }
    }
    Timer { id:startup;interval:10000;onTriggered:{root.error=Errors.message("BackendUnavailable");bridge.running=false} }
    Timer { id:challengeExpiry;interval:45000;onTriggered:root.answer(false,"") }
    Process {
        id:bridge;stdinEnabled:true
        command:["python3","-u",root.helperPath]
        onStarted:{root.ready=false;startup.restart()}
        stdout:SplitParser { onRead:data=>{try{root.receive(JSON.parse(data))}catch(_){root.error=Errors.message("InvalidResponse");ledger.cancelAll("InvalidResponse")}} }
        // Never forward raw helper output into the shell journal.
        stderr:SplitParser {onRead:data=>root.error=Errors.message("BackendUnavailable")}
        onExited:{startup.stop();challengeExpiry.stop();root.ready=false;root.prompt=null;ledger.cancelAll("BackendExited");if(consumers.active)root.error=Errors.message("BackendExited")}
    }
}
