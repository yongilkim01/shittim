pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../components/launcher"

Scope {
    id: root
    property bool opened: false
    property var targetScreen: null
    property bool ready: false
    property bool launching: false
    property string error: ""
    property int generation: 0
    property int sequence: 0
    property int launchGeneration: 0
    signal applicationLaunched()
    signal launchFinished(string appId, bool ok)
    property string launchAppId: ""
    property var dockFavorites: []
    property var dockWindowClasses: ({})
    property string dockError: ""
    readonly property alias model: search
    readonly property string helperPath: Quickshell.shellDir + "/../scripts/launcher-service.py"
    LauncherModel { id: search }
    function show() {
        if (opened) return
        ControlState.close()
        const focused = Hyprland.focusedMonitor
        targetScreen = Quickshell.screens.find(screen => focused !== null && screen.name === focused.name) || Quickshell.screens[0] || null
        if (targetScreen === null) return
        generation++
        search.reset()
        error = ""
        opened = true
        if (!bridge.running) bridge.running = true
    }
    function close() { opened = false; search.reset() }
    function toggle() { if (opened) close(); else show() }
    function refresh() {
        error = ""
        if (!bridge.running) { ready = false; bridge.running = true }
        else bridge.write(JSON.stringify({action: "refresh"}) + "\n")
    }
    function launch(appId) {
        if (!ready || launching || !search.applications.some(app => app.id === appId)) return
        launching = true
        error = ""
        launchGeneration = generation
        launchAppId = appId
        sequence++
        bridge.write(JSON.stringify({action: "launch", id: appId, request: sequence}) + "\n")
    }
    function iconSource(app) {
        if (app.iconFile) return app.iconFile
        for (const name of app.icons || []) {
            const path = Quickshell.iconPath(name, true)
            if (path.length > 0) return path
        }
        return Quickshell.iconPath("application-x-executable", true)
    }
    function errorText(code) {
        if (code === "GioUnavailable") return "python-gobject 설치를 확인하세요. F5로 다시 시도합니다."
        if (code === "ApplicationMissing") return "앱이 제거되었거나 숨겨졌습니다. 목록을 갱신했습니다."
        if (code === "LaunchFailed") return "앱 실행 실패. 실행 파일·작업 경로·터미널 설정을 확인하세요."
        return "앱 목록을 읽지 못했습니다. F5로 다시 시도하세요."
    }
    Connections { target: ControlState; function onOpenedChanged() { if (ControlState.opened) root.close() } }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.opened && (root.targetScreen === null || Quickshell.screens.indexOf(root.targetScreen) < 0)) root.close()
        }
    }
    Process {
        id: bridge
        command: ["python3", "-u", root.helperPath]
        stdinEnabled: true; running: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const message = JSON.parse(data)
                    if (message.event === "catalogue") { search.applications = message.applications; root.ready = true }
                    else if (message.event === "dock") { root.dockFavorites = message.favorites; root.dockWindowClasses = message.windowClasses; root.dockError = message.error ? "즐겨찾기 설정 형식을 확인하세요." : "" }
                    else if (message.event === "error") root.error = root.errorText(message.error)
                    else if (message.event === "launched" && message.request === root.sequence) {
                        root.launching = false
                        if (message.ok) root.applicationLaunched()
                        if (message.ok && root.launchGeneration === root.generation) root.close()
                        else if (!message.ok) root.error = root.errorText(message.error)
                        root.launchFinished(root.launchAppId, message.ok)
                    }
                } catch (_) { root.error = "앱 서비스 응답을 처리하지 못했습니다." }
            }
        }
        stderr: SplitParser { onRead: data => { root.error = "앱 서비스 실행 오류. 설치 상태를 확인하세요." } }
        onExited: {
            const interrupted = root.launching
            root.ready = false; root.launching = false; root.error = "앱 서비스가 종료되었습니다. python-gobject 설치 후 F5를 누르세요."
            if (interrupted) root.launchFinished(root.launchAppId, false)
        }
    }
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function show(): void { root.show() }
        function hide(): void { root.close() }
        function reload(): void { root.refresh() }
        function status(): string { return JSON.stringify({opened: root.opened, ready: root.ready, applications: search.applications.length, launching: root.launching}) }
    }
}
