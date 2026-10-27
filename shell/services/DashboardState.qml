pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../components/dashboard"
import "../core"

Scope {
    id: root
    readonly property bool opened: session.active
    property string page: "system"
    readonly property var anchorWindow: session.anchorWindow
    readonly property var targetScreen: session.screen
    readonly property alias panelSession: session
    PanelSession { id:session;coordinator:InteractionState;name:"dashboard" }
    readonly property alias model: metrics
    readonly property bool measuring: opened && page === "system"
    readonly property bool controlsActive: opened && ["bluetooth", "display", "power", "settings"].indexOf(page) >= 0
    onMeasuringChanged: if (measuring) metrics.reset()
    function close() { session.close() }
    function show(window, item) {
        page = "system"
        session.open(InteractionState.screenFor(window),window,item)
    }
    function toggle(window, item) { if (opened && anchorWindow === window) close(); else show(window,item) }
    function select(destination) {
        if (["system", "apps", "bluetooth", "display", "network", "audio", "power", "settings"].indexOf(destination) >= 0) page = destination
    }
    DashboardModel { id: metrics }
    Process {
        id: bridge
        command: ["python3", "-u", Quickshell.shellDir + "/../scripts/dashboard-service.py"]
        running: root.measuring
        onStarted: metrics.reset()
        stdout: SplitParser {
            onRead: data => {
                try { if (root.measuring) metrics.receive(JSON.parse(data)) }
                catch (_) { metrics.failure("시스템 정보 응답을 처리하지 못했습니다.") }
            }
        }
        stderr: SplitParser { onRead: data => { metrics.failure("시스템 측정 오류. Python 설치와 장치 접근 권한을 확인하세요.") } }
        onExited: if (root.measuring) metrics.failure("측정 서비스가 종료되었습니다. 대시보드를 다시 열어 주세요.")
        onRunningChanged: if (root.measuring && !running && !metrics.ready) metrics.failure("측정 서비스를 시작하지 못했습니다. Python 설치를 확인하고 다시 열어 주세요.")
    }
    onPageChanged: if (page === "apps") LauncherState.model.reset()
    IpcHandler {
        target: "dashboard"
        function toggle(): void { if (root.opened) root.close(); else root.show(null) }
        function show(): void { root.show(null) }
        function hide(): void { root.close() }
        function status(): string { return JSON.stringify({opened: root.opened, page: root.page, measuring: root.measuring, process: bridge.running, pid: Number(bridge.processId || 0), ready: metrics.ready, samples: metrics.samples.length}) }
    }
}
