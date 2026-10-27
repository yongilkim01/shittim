import QtQuick

// Bounded request identities; late responses cannot complete a newer operation.
QtObject {
    id:root
    property var _entries: ({})
    readonly property var entries:_entries
    property int sequence:0
    property var now:function(){return Date.now()}
    readonly property bool busy:Object.keys(entries).length>0
    signal finished(var result)
    function begin(operation, timeout, target) {
        if(Object.keys(entries).length>=64)return 0
        const id=++sequence,next=Object.assign({},entries)
        next[id]={id:id,operation:operation,target:target || "",deadline:now()+Math.max(1,timeout)}
        _entries=next;schedule();return id
    }
    function settle(id, status, code, retryable, detail) {
        const request=entries[id]
        if(!request)return false
        const next=Object.assign({},entries);delete next[id];_entries=next;schedule()
        finished(Object.assign({},detail || {},{version:1,id:Number(id),operation:request.operation,target:request.target,
            status:status,ok:status==="success",code:code || "",retryable:Boolean(retryable)}))
        return true
    }
    function complete(id, ok, code, retryable, detail) { return settle(id,ok ? "success" : "failure",code,retryable,detail) }
    function expire() {
        const time=now()
        for(const id of Object.keys(entries)){
            const request=entries[id]
            if(request && request.deadline<=time)settle(id,"timeout","RequestTimeout",false)
        }
    }
    function cancelAll(code) { for(const id of Object.keys(entries))settle(id,"cancelled",code || "Cancelled",false) }
    function schedule() {
        expiry.stop()
        const deadlines=Object.values(entries).map(entry=>entry.deadline)
        if(deadlines.length){expiry.interval=Math.max(1,Math.min(2147483647,Math.min.apply(null,deadlines)-now()));expiry.start()}
    }
    property Timer expiry:Timer { onTriggered:root.expire() }
}
