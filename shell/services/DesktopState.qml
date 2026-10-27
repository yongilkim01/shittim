pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../core/ActionErrors.js" as Errors

Scope {
    id: root
    property var entries: []
    property var positions: ({})
    readonly property bool busy:requests.busy
    property bool ready: false
    property string error: ""
    property string directory: ""
    property bool tracingInput: false
    property var inputSurfaces: []
    RequestLedger {id:requests;onFinished:result=>{if(!result.ok)root.error=Errors.message(result.code)}}
    Timer {id:startup;running:true;interval:10000;onTriggered:{root.error=Errors.message("BackendUnavailable");bridge.running=false}}
    function registerInput(trace) { inputSurfaces=inputSurfaces.concat([trace]) }
    function unregisterInput(trace) { inputSurfaces=inputSurfaces.filter(candidate=>candidate!==trace) }
    function focusStatus() {
        return JSON.stringify({protocol:1,capturing:tracingInput,surfaces:inputSurfaces.map(trace=>trace.snapshot())})
    }
    // Diagnostics expire even if the requesting process exits before stopping them.
    Timer { id:traceExpiry;interval:35000;onTriggered:root.tracingInput=false }
    function send(action, values) {
        error=""
        if (!bridge.running) { error="바탕화면 서비스를 다시 시작하려면 F5를 누르세요."; return }
        const id=action==="refresh" ? 0 : requests.begin(action,30000,"")
        if(action!=="refresh" && !id){error=Errors.message("QueueFull");return}
        bridge.write(JSON.stringify(Object.assign({action:action,id:id},values || {})) + "\n")
    }
    function refresh() { if (!bridge.running) {startup.restart();bridge.running=true} else send("refresh") }
    function save(screen, values) { send("positions",{screen:screen,positions:values}) }
    Process {
        id: bridge; running:true; stdinEnabled:true
        onStarted:startup.restart()
        command:["python3","-u",Quickshell.shellDir + "/../scripts/desktop-service.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result=JSON.parse(data)
                    if (result.event === "desktop") { startup.stop();root.entries=result.entries; root.positions=result.positions; root.directory=result.directory; root.ready=true }
                    else if (result.event === "positions") root.positions=result.positions
                    else if (result.event === "result") requests.complete(result.id,result.ok,result.error,false)
                    else if (result.event === "error") root.error=result.error === "DesktopDirectoryUnavailable" ? "XDG 바탕화면 폴더 설정을 확인하세요." : result.error === "ProtectedShortcut" ? "기본 바로가기는 이동하거나 삭제할 수 없습니다." : "파일 작업을 완료하지 못했습니다. Nemo와 파일 권한을 확인하세요. (" + result.error + ")"
                } catch (_) { requests.cancelAll("InvalidResponse");root.error="바탕화면 응답을 읽지 못했습니다." }
            }
        }
        onExited: {startup.stop();requests.cancelAll("BackendExited");root.ready=false; root.error="바탕화면 서비스가 종료되었습니다. F5로 다시 시도하세요." }
    }
    IpcHandler {
        target:"desktop"
        function reload(): void { root.refresh() }
        function status(): string { return JSON.stringify({ready:root.ready,entries:root.entries.length,busy:root.busy,error:root.error.length>0}) }
        function focusStatus(): string { return root.focusStatus() }
        function startInputTrace(): string { root.tracingInput=false;root.tracingInput=true;traceExpiry.restart();return root.focusStatus() }
        function stopInputTrace(): string { root.tracingInput=false;traceExpiry.stop();return root.focusStatus() }
    }
}
