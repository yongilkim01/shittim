pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../components/windows"

Scope {
    id: root
    property bool opened: false
    property bool cycling: false
    property var targetScreen: null
    property var recent: []
    property string error: ""
    property var pending: []
    property string response: ""
    property var requests: []
    signal showing()
    readonly property bool busy: action.running || pending.length > 0
    readonly property alias model: selection
    readonly property var windows: Hyprland.toplevels.values.map(window => {
        const ipc = window.lastIpcObject
        return {handle: window, address: window.address, activated: window.activated,
            title: window.title, appId: window.wayland ? window.wayland.appId : "",
            className: ipc.class || "", initialClass: ipc.initialClass || "",
            floating: Boolean(ipc.floating), fullscreen: Number(ipc.fullscreen || 0),
            maximized: Number(ipc.fullscreen || 0)===1 || (ipc.tags || []).indexOf("shittim-maximized")>=0,
            monitor: Number(ipc.monitor), at: ipc.at || [0,0], size: ipc.size || [0,0],
            workspace: ipc.workspace ? ipc.workspace.name : "",
            hidden: ipc.workspace ? /^special:shittim-hidden-\d+-[0-3]-[0-3]-[0-9a-f]+$/.test(ipc.workspace.name) : false}
    }).filter(window => /^[0-9a-fA-F]+$/.test(window.address))
    WindowModel { id: selection; windows: root.windows; recent: root.recent }
    Component.onCompleted: {
        if (Hyprland.activeToplevel) recent = [Hyprland.activeToplevel.address]
        Hyprland.refreshToplevels()
        workAreaRefresh.restart()
    }
    function close() { opened = false; cycling = false }
    function show(addresses, cycle, screen) {
        showing()
        ControlState.close(); LauncherState.close(); NotificationState.close(); DashboardState.close()
        const focused = Hyprland.focusedMonitor
        targetScreen = screen || Quickshell.screens.find(candidate => focused && candidate.name === focused.name) || Quickshell.screens[0] || null
        if (!targetScreen) return
        Hyprland.refreshToplevels()
        selection.allowedAddresses = addresses || []
        error = ""
        cycling = Boolean(cycle)
        selection.start(cycle || 0)
        opened = true
    }
    function cycle(direction) {
        if (opened && cycling) selection.step(direction)
        else show([], direction)
    }
    function commit() { if (opened && cycling && selection.selected) perform("activate", selection.selected.address) }
    function perform(operation, address) {
        if (!/^[0-9a-fA-F]{1,16}$/.test(address) || ["activate", "hide", "close", "maximize", "fullscreen", "tile", "fit"].indexOf(operation) < 0) return false
        if (busy) { error = "창 명령을 처리 중입니다. 잠시 뒤 다시 시도하세요."; return false }
        close()
        pending = ["python3", Quickshell.shellDir + "/../scripts/window-service.py", operation, address]
        Qt.callLater(() => { response = ""; action.command = pending; pending = []; action.running = true })
        return true
    }
    function minimizeRequest(data) {
        const parts = data.split(","), address = parts[0].replace(/^0x/, "")
        if (parts.length !== 2 || !/^[0-9a-fA-F]{1,16}$/.test(address) || ["0", "1"].indexOf(parts[1]) < 0) return
        const request = {operation: parts[1] === "1" ? "hide" : "activate", address: address}
        if (!requests.some(item => item.operation === request.operation && item.address === address)) requests = requests.concat([request]).slice(-64)
        requestTimer.restart()
    }
    Timer {
        id: requestTimer; interval: 30
        onTriggered: {
            if (root.busy) return
            if (root.requests.length) {
                const request = root.requests[0]; root.requests = root.requests.slice(1)
                root.perform(request.operation, request.address)
            }
        }
    }
    Timer { id: refresh; interval: 60; onTriggered: Hyprland.refreshToplevels() }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const window = Hyprland.activeToplevel
            if (window) root.recent = [window.address].concat(root.recent.filter(address => address !== window.address)).slice(0, 512)
        }
        function onRawEvent(event) {
            if (event.name === "minimized" || event.name === "minimize") root.minimizeRequest(event.data)
            if (["openwindow", "closewindow", "movewindow", "movewindowv2", "changefloatingmode", "fullscreen", "monitoradded", "monitorremoved"].indexOf(event.name) >= 0 || (event.name==="custom" && event.data.indexOf("shittim-window-state,")===0)) refresh.restart()
            if (["monitoradded", "monitorremoved", "configreloaded", "fullscreen"].indexOf(event.name)>=0)workAreaRefresh.restart()
        }
    }
    Timer { id:workAreaRefresh;interval:700;onTriggered:if(!reflow.running)reflow.running=true }
    Process {
        id:reflow;command:["python3",Quickshell.shellDir+"/../scripts/window-service.py","reflow"]
        onExited:Hyprland.refreshToplevels()
    }
    Connections { target: ControlState; function onOpenedChanged() { if (ControlState.opened) root.close() } }
    Connections { target: LauncherState; function onOpenedChanged() { if (LauncherState.opened) root.close() } }
    Connections { target: NotificationState; function onOpenedChanged() { if (NotificationState.opened) root.close() } }
    Connections { target: DashboardState; function onOpenedChanged() { if (DashboardState.opened) root.close() } }
    Connections { target: Quickshell; function onScreensChanged() { if (root.opened && Quickshell.screens.indexOf(root.targetScreen) < 0) root.close() } }
    Process {
        id: action
        stdout: StdioCollector { onStreamFinished: root.response = text }
        onExited: (code, status) => {
            let ok = false, reason = ""
            try { const result = JSON.parse(root.response); ok = code === 0 && result.ok === true; reason = result.error || "" } catch (_) {}
            Hyprland.refreshToplevels()
            if (!ok) {
                root.show([], 0)
                root.error = reason === "CannotHideSpecialOrGroupedWindow" ? "고정·그룹·특수 워크스페이스 창은 숨기지 않습니다."
                    : reason === "WindowClosed" ? "창이 닫혔습니다. 다른 창을 선택하세요."
                    : reason === "ExitFullscreenBeforeMaximize" ? "전체 화면을 해제한 뒤 최대화하세요."
                    : reason === "CannotMaximizePinnedOrGroupedWindow" ? "고정·그룹 창은 먼저 고정 또는 그룹을 해제하세요."
                    : reason === "InvalidRestoreGeometry" ? "이 창의 복원 위치를 읽지 못했습니다. 현재 창은 유지합니다."
                    : "창 명령이 실패했습니다. 창·모니터 상태를 확인하고 다시 선택하세요."
            }
            if (root.requests.length) requestTimer.restart()
        }
    }
    IpcHandler {
        target: "windows"
        function nativeMinimize(address: string, state: string): void { root.minimizeRequest(address.replace(/^0x/, "") + "," + state) }
        function show(): void { root.show([], 0) }
        function next(): void { root.cycle(1) }
        function previous(): void { root.cycle(-1) }
        function commit(): void { root.commit() }
        function status(): string { return JSON.stringify({opened: root.opened, windows: root.windows.length, hidden: root.windows.filter(window => window.hidden).length}) }
    }
}
