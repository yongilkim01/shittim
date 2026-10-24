pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    property var entries: []
    property var positions: ({})
    property bool busy: false
    property bool ready: false
    property string error: ""
    property string directory: ""
    function send(action, values) {
        error=""
        if (!bridge.running) { error="바탕화면 서비스를 다시 시작하려면 F5를 누르세요."; return }
        bridge.write(JSON.stringify(Object.assign({action:action},values || {})) + "\n")
    }
    function refresh() { if (!bridge.running) bridge.running=true; else send("refresh") }
    function save(screen, values) { send("positions",{screen:screen,positions:values}) }
    Process {
        id: bridge; running:true; stdinEnabled:true
        command:["python3","-u",Quickshell.shellDir + "/../scripts/desktop-service.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result=JSON.parse(data)
                    if (result.event === "desktop") { root.entries=result.entries; root.positions=result.positions; root.directory=result.directory; root.ready=true }
                    else if (result.event === "positions") root.positions=result.positions
                    else if (result.event === "busy") root.busy=result.value
                    else if (result.event === "error") root.error=result.error === "DesktopDirectoryUnavailable" ? "XDG 바탕화면 폴더 설정을 확인하세요." : result.error === "ProtectedShortcut" ? "기본 바로가기는 이동하거나 삭제할 수 없습니다." : "파일 작업을 완료하지 못했습니다. Nemo와 파일 권한을 확인하세요. (" + result.error + ")"
                } catch (_) { root.error="바탕화면 응답을 읽지 못했습니다." }
            }
        }
        onExited: { root.busy=false; root.ready=false; root.error="바탕화면 서비스가 종료되었습니다. F5로 다시 시도하세요." }
    }
    IpcHandler {
        target:"desktop"
        function reload(): void { root.refresh() }
        function status(): string { return JSON.stringify({ready:root.ready,entries:root.entries.length,busy:root.busy,error:root.error.length>0}) }
    }
}
