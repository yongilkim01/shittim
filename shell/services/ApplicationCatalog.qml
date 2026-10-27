pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/launcher/Diagnostics.js" as Diagnostics
import "../components/launcher/IconResolver.js" as Icons
import "../ui/AssetPaths.js" as AssetPaths
import "../core"
import "../core/ActionErrors.js" as Errors

Scope {
    id: root
    property bool ready: false
    property bool launching: false
    property string error: ""
    property int sequence: 0
    signal launchFinished(string appId, bool ok)
    property string launchAppId: ""
    property var dockFavorites: []
    property var dockWindowClasses: ({})
    property string dockError: ""
    readonly property string helperPath: Quickshell.shellDir + "/../scripts/launcher-service.py"
    property var applications:[]
    RequestLedger {
        id:requests
        onFinished:result=>{
            root.launching=false
            if(result.ok)root.error=""
            else root.error=result.code==="ApplicationMissing" || result.code==="LaunchFailed" ? root.errorText(result.code) : Errors.message(result.code)
            root.launchFinished(root.launchAppId,result.ok)
        }
    }
    Timer {id:startup;running:true;interval:10000;onTriggered:{root.error=Errors.message("BackendUnavailable");bridge.running=false}}
    function ensure(){if(!bridge.running){startup.restart();bridge.running=true}}
    function clearError(){error=""}
    function refresh() {
        error = ""
        if (!bridge.running) { ready = false; startup.restart();bridge.running = true }
        else bridge.write(JSON.stringify({action: "refresh"}) + "\n")
    }
    function launch(appId, newWindow) {
        if (!ready || launching || !applications.some(app => app.id === appId)) return false
        launching = true
        error = ""
        launchAppId = appId
        sequence=requests.begin(newWindow ? "new-window" : "launch",15000,appId)
        bridge.write(JSON.stringify({action: newWindow ? "new-window" : "launch", id: appId, request: sequence}) + "\n");return true
    }
    function dockAction(action, appId, index) {
        if (ready && ["pin", "unpin", "reorder"].indexOf(action) >= 0)
            bridge.write(JSON.stringify({action: action, id: appId, index: index}) + "\n")
    }
    function assetSource(relative) { return AssetPaths.asset(Quickshell.shellDir, relative) }
    function iconSource(app) {
        return Icons.resolve(app, name => Quickshell.iconPath(name, true),
            name => root.assetSource("icons/Shittim-HUD/scalable/apps/" + name + ".svg"),
            name => root.assetSource("icons/Shittim-HUD/scalable/places/" + name + ".svg"))
    }
    function errorText(code) {
        if (code === "GioUnavailable") return "python-gobject 설치를 확인하세요. F5로 다시 시도합니다."
        if (code === "ApplicationMissing") return "앱이 제거되었거나 숨겨졌습니다. 목록을 갱신했습니다."
        if (code === "LaunchFailed") return "앱 실행 실패. 실행 파일·작업 경로·터미널 설정을 확인하세요."
        return "앱 목록을 읽지 못했습니다. F5로 다시 시도하세요."
    }
    Process {
        id: bridge
        command: ["python3", "-u", root.helperPath]
        stdinEnabled: true; running: true
        onStarted:startup.restart()
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    if (message.event === "catalogue") { startup.stop();root.applications = message.applications; root.ready = true }
                    else if (message.event === "dock") { root.dockFavorites = message.favorites; root.dockWindowClasses = message.windowClasses; root.dockError = message.error ? "즐겨찾기 설정 형식을 확인하세요." : "" }
                    else if (message.event === "error") root.error = root.errorText(message.error)
                    else if (message.event === "launched" && message.request === root.sequence) {
                        requests.complete(message.request,message.ok,message.error,false)
                    }
                } catch (_) { root.error = Errors.message("InvalidResponse");requests.cancelAll("InvalidResponse") }
            }
        }
        stderr: SplitParser { onRead: data => { if (Diagnostics.isFailure(data)) root.error = "앱 서비스 내부 오류. F5로 새로고침하고 실행 상태를 확인하세요." } }
        onExited: {
            startup.stop();requests.cancelAll("BackendExited")
            root.ready = false; root.launching = false; root.error = "앱 서비스가 종료되었습니다. python-gobject 설치 후 F5를 누르세요."
        }
    }
}
