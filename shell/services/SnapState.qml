pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Scope {
    id:root
    property var targetScreen:null
    property var geometry:null
    property var queue:[]
    property var current:null
    property int generation:0
    property double lastSequence:0
    property double lastCommitSequence:0
    property string response:""
    property string error:""
    function event(state,address,zone,monitor,sequence) {
        if (!/^0x[0-9a-fA-F]{1,16}$/.test(address) || ["preview","commit","clear"].indexOf(state)<0) return
        const order=Number(sequence)
        if (!Number.isSafeInteger(order) || (state!=="commit" && order<=lastSequence) || (state==="commit" && order<=lastCommitSequence)) return
        lastSequence=Math.max(lastSequence,order)
        if (state==="commit") lastCommitSequence=order
        generation++
        if (state==="clear" || zone==="none") { geometry=null; return }
        if (["left","right","top-left","top-right","bottom-left","bottom-right","top"].indexOf(zone)<0 || !Number.isInteger(monitor)) return
        if(queue.filter(item=>item.state==="commit").length>=32){error="스냅 요청이 많습니다. 현재 창 상태를 확인한 뒤 다시 시도하세요.";expiry.restart();return}
        queue=queue.filter(item=>item.state==="commit").concat([{state:state,address:address,zone:zone,monitor:monitor,generation:generation}])
        if (!action.busy) next()
    }
    function next() {
        if (queue.length===0 || action.busy || current) return
        current=queue[0]; queue=queue.slice(1); response=""
        action.submit(current.state==="commit" ? "snap" : "snap-preview",current.address,[current.zone,String(current.monitor)])
    }
    WindowClient {
        id:action
        onFinished:reply=>{
            try {
                const result=reply.data || {}
                if (reply.ok && result.ok && root.current.state==="preview" && root.current.generation===root.generation) {
                    root.targetScreen=Quickshell.screens.find(screen=>screen.name===result.monitor.name) || null
                    const g=result.geometry
                    root.geometry=[g[0]-result.monitor.x,g[1]-result.monitor.y,g[2],g[3]]
                    expiry.restart()
                } else if (root.current.state==="commit" && (!reply.ok || !result.ok)) { root.error="창 스냅을 적용하지 못했습니다."; expiry.restart() }
            } catch (_) { root.geometry=null }
            root.current=null;Qt.callLater(root.next)
        }
    }
    Timer { id:expiry; interval:30000; onTriggered:{root.geometry=null;root.error=""} }
    IpcHandler {
        target:"snap"
        function event(state:string,address:string,zone:string,monitor:int,sequence:string):void { root.event(state,address,zone,monitor,sequence) }
        function status():string { return JSON.stringify({preview:root.geometry!==null,busy:action.busy,error:root.error.length>0}) }
    }
}
