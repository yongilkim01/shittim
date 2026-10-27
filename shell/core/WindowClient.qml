import QtQuick
import Quickshell
import Quickshell.Io
import "ActionErrors.js" as Errors

Scope {
    id:root
    property var queue:[]
    property var current:null
    property string response:""
    property string error:""
    property string errorCode:""
    readonly property bool busy:ledger.busy
    readonly property var requests:ledger.entries
    signal finished(var result)
    function submit(operation, address, extra) {
        if(["activate","hide","close","maximize","restore","fullscreen","tile","fit","snap","snap-preview","reflow"].indexOf(operation)<0
            || (address!=="active" && !/^(0x)?[0-9a-fA-F]{1,16}$/.test(address || "")))return 0
        const id=ledger.begin(operation,30000,address)
        if(!id){errorCode="QueueFull";error=Errors.message(errorCode);return 0}
        queue=queue.concat([{id:id,operation:operation,target:address,extra:extra || []}]);Qt.callLater(next);return id
    }
    function next() {
        if(process.running || current || !queue.length)return
        current=queue[0];queue=queue.slice(1)
        if(!ledger.entries[current.id]){current=null;Qt.callLater(next);return}
        response="";error="";errorCode=""
        process.command=["python3",Quickshell.shellDir+"/../scripts/window-service.py",current.operation,current.target]
            .concat(current.extra).concat(["--request",String(current.id)])
        process.running=true
    }
    RequestLedger {
        id:ledger
        onFinished:result=>{
            if(result.status==="timeout" && root.current && root.current.id===result.id){
                if(process.running){process.running=false;killTimer.restart()}
                else {root.current=null;Qt.callLater(root.next)}
            }
            if(!result.ok){root.errorCode=result.code;root.error=Errors.message(result.code)}
            root.finished(result)
        }
    }
    Timer {id:killTimer;interval:1000;onTriggered:if(process.running)process.signal(9)}
    Process {
        id:process
        stdout:StdioCollector { onStreamFinished:root.response=text }
        onExited:(code,status)=>{
            killTimer.stop()
            const request=root.current
            if(!request)return
            try {
                const result=JSON.parse(root.response)
                if(result.version!==1 || String(result.request)!==String(request.id))throw new Error("InvalidResponse")
                ledger.complete(request.id,code===0 && result.ok,result.code || result.error || (code ? "BackendExited" : ""),result.retryable,{state:result.state || null,verified:result.verified===true,data:result})
            } catch(_) {ledger.complete(request.id,false,"InvalidResponse",false)}
            root.current=null;Qt.callLater(root.next)
        }
    }
}
