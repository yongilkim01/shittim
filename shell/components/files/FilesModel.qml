import QtQuick
import "../../core"
import "../../core/ActionErrors.js" as Errors

QtObject {
    id: root
    property var tabs: []
    property int activeIndex: 0
    property int nextTab: 0
    property int serial: 0
    property int operationRequest: -1
    property string homeUri: ""
    property var places: []
    property var selected: []
    property string query: ""
    property string viewMode: "icons"
    property string sortBy: "name"
    property bool showHidden: false
    property string error: ""
    readonly property var current: tabs[activeIndex] || null
    readonly property bool busy: operationRequest >= 0 || (current !== null && current.pending)
    readonly property bool writable: current !== null && current.writable
    readonly property bool inTrash: current !== null && current.uri.indexOf("trash:") === 0
    readonly property var entries: {
        if (!current) return []
        const needle=query.toLocaleLowerCase()
        return current.entries.filter(entry => (showHidden || !entry.hidden) && entry.name.toLocaleLowerCase().indexOf(needle)>=0).slice().sort((a,b)=> {
            if (a.directory !== b.directory) return a.directory ? -1 : 1
            if (sortBy === "size" && a.size !== b.size) return b.size-a.size
            if (sortBy === "modified" && a.modified !== b.modified) return b.modified-a.modified
            return a.name.localeCompare(b.name,undefined,{numeric:true,sensitivity:"base"})
        })
    }
    signal requested(string action, var values)
    signal closeRequested()
    property RequestLedger requests: RequestLedger {
        onFinished: result => {
            if(result.ok)return
            if(root.operationRequest===result.id)root.operationRequest=-1
            root.tabs=root.tabs.map(tab=>tab.request===result.id ? Object.assign({},tab,{pending:false,dirty:false}) : tab)
            if(result.status==="timeout" || result.status==="cancelled" && ["Cancelled","Superseded"].indexOf(result.code)<0)root.error=Errors.message(result.code)
        }
    }
    function failRequests(code) { requests.cancelAll(code); operationRequest=-1;tabs=tabs.map(tab=>Object.assign({},tab,{dirty:true,pending:false})) }
    function changed(tab) { tabs=tabs.map(candidate => candidate.id===tab.id ? Object.assign({},tab) : candidate) }
    function selectTab(index) { activeIndex=index; selected=[]; query=""; if (current && current.dirty) refresh() }
    function open(uri, newTab) {
        if (!current || newTab) {
            if (tabs.length>=16) { error="탭은 16개까지 열 수 있습니다."; return }
            tabs=tabs.concat([{id:++nextTab,name:"Home",uri:"",entries:[],breadcrumbs:[],history:[],position:-1,parent:"",writable:false,pending:false,request:0,dirty:false}])
            selectTab(tabs.length-1)
        }
        navigate(uri || homeUri)
    }
    function navigate(uri, historyIndex, keepView) {
        if (!current) return
        error=""; if(!keepView){selected=[]; query=""}
        if(current.pending)requests.settle(current.request,"cancelled","Superseded",false)
        const request=requests.begin("browse",15000,String(current.id))
        if(!request){error=Errors.message("QueueFull");return}
        const tab=Object.assign({},current,{pending:true,request:request,historyTarget:historyIndex===undefined ? -1 : historyIndex})
        changed(tab); requested("browse",{tab:tab.id,request:tab.request,uri:uri})
    }
    function refresh() { if (current) navigate(current.uri,current.position,true) }
    function history(delta) { if (current && current.position+delta>=0 && current.position+delta<current.history.length) navigate(current.history[current.position+delta],current.position+delta) }
    function up() { if (current && current.parent) navigate(current.parent) }
    function closeTab(index) {
        if (!tabs[index]) return
        if(tabs[index].pending)requests.settle(tabs[index].request,"cancelled","Cancelled",false)
        requested("close-tab",{tab:tabs[index].id,request:++serial})
        tabs=tabs.filter((_,i)=>i!==index); activeIndex=Math.max(0,Math.min(activeIndex,tabs.length-1)); selected=[]
        if (tabs.length===0) closeRequested()
    }
    function select(id, index, modifiers) {
        if (modifiers & Qt.ShiftModifier && selected.length>0) {
            const anchor=Math.max(0,entries.findIndex(entry=>entry.id===selected[0]))
            selected=entries.slice(Math.min(anchor,index),Math.max(anchor,index)+1).map(entry=>entry.id)
        } else if (modifiers & Qt.ControlModifier) selected=selected.indexOf(id)>=0 ? selected.filter(value=>value!==id) : selected.concat([id])
        else selected=[id]
    }
    function moveSelection(delta) {
        if (!entries.length) return
        const index=entries.findIndex(entry=>entry.id===selected[selected.length-1])
        selected=[entries[Math.max(0,Math.min(entries.length-1,index+delta))].id]
    }
    function activate(entry) { if (entry.directory) navigate(entry.uri); else { selected=[entry.id]; action("open") } }
    function action(name, values) {
        if (!current || busy) return
        operationRequest=requests.begin(name,30000,String(current.id)); error=""
        if(!operationRequest){operationRequest=-1;error=Errors.message("QueueFull");return}
        requested(name,Object.assign({tab:current.id,request:operationRequest,ids:selected.slice()},values || {}))
    }
    function accept(message) {
        if (message.event==="ready") { homeUri=message.home; places=message.places; return }
        if (message.event==="places") { places=message.places; return }
        const index=tabs.findIndex(tab=>tab.id===message.tab)
        if (index<0) { if ((message.event==="done" || message.event==="error") && operationRequest===message.request) {requests.complete(message.request,message.event==="done",message.error,false);operationRequest=-1} return }
        const tab=Object.assign({},tabs[index])
        if (message.event==="changed") { tab.dirty=true; changed(tab); return }
        if (message.event==="listing") {
            if (!tab.pending || tab.request!==message.request || !requests.complete(message.request,true)) return
            if (tab.historyTarget>=0) tab.position=tab.historyTarget
            else if (tab.uri!==message.uri || tab.position<0) { tab.history=tab.history.slice(0,tab.position+1).concat([message.uri]); tab.position=tab.history.length-1 }
            Object.assign(tab,{name:message.name,uri:message.uri,parent:message.parent,entries:message.entries,breadcrumbs:message.breadcrumbs,writable:message.writable,pending:false,dirty:false,truncated:message.truncated})
            changed(tab); selected=selected.filter(id=>current && current.entries.some(entry=>entry.id===id))
        } else if (message.event==="done") {
            if (operationRequest===message.request && requests.complete(message.request,true)) operationRequest=-1
        } else if (message.event==="error") {
            if (tab.request!==message.request && operationRequest!==message.request) return
            if(!requests.complete(message.request,false,message.error,false))return
            if (operationRequest===message.request) operationRequest=-1
            else { tab.pending=false; tab.dirty=false; changed(tab) }
            const messages={PermissionDenied:"이 위치에 접근할 권한이 없습니다.",NotFound:"파일이나 폴더를 찾을 수 없습니다.",AlreadyExists:"같은 이름이 이미 있습니다. 기존 파일은 덮어쓰지 않았습니다.",NotDirectory:"폴더를 선택하세요.",ReadOnlyLocation:"이 위치의 파일 작업은 Nemo에서 열어 사용할 수 있습니다.",ClipboardHasNoFiles:"클립보드에 복사한 파일이 없습니다.",InvalidName:"사용할 수 없는 파일 이름입니다.",RestoreUnavailable:"원래 위치로 복원할 수 없습니다."}
            error=messages[message.error] || "파일 작업을 완료하지 못했습니다. 권한·연결 상태를 확인하세요. ("+message.error+")"
        }
    }
}
