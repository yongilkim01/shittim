pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../components/windows"
import "../core"

Scope {
    id: root
    readonly property bool opened: session.active
    property bool cycling: false
    readonly property var targetScreen: session.screen
    readonly property alias panelSession: session
    PanelSession { id:session;coordinator:InteractionState;name:"windows";onRevoked:root.cycling=false }
    readonly property var recent:WindowCatalog.recent
    property string error: ""
    property var requests: []
    readonly property bool busy:WindowCommands.busy
    readonly property alias model: selection
    readonly property var windows:WindowCatalog.windows
    WindowModel { id: selection; windows: root.windows; recent: root.recent }
    function close() { session.close(); cycling = false }
    function show(addresses, cycle, screen) {
        const output=screen || InteractionState.screenFor(null)
        if (!output) return
        Hyprland.refreshToplevels()
        selection.allowedAddresses = addresses || []
        error = ""
        cycling = Boolean(cycle)
        selection.start(cycle || 0)
        session.open(output)
    }
    function cycle(direction) {
        if (opened && cycling) selection.step(direction)
        else show([], direction)
    }
    function commit() { if (opened && cycling && selection.selected) perform("activate", selection.selected.address) }
    function perform(operation, address) {
        if (!/^[0-9a-fA-F]{1,16}$/.test(address) || ["activate", "hide", "close", "maximize", "fullscreen", "tile", "fit"].indexOf(operation) < 0) return false
        close()
        return WindowCommands.submit(operation,address)>0
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
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "minimized" || event.name === "minimize") root.minimizeRequest(event.data)
        }
    }
    Connections {
        target:WindowCommands
        function onFinished(result) {
            if(!result.ok)root.error=WindowCommands.error
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
