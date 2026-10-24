pragma Singleton
import QtQuick
import Quickshell

Scope {
    id: root
    property string appId: ""
    property string mode: ""
    property var screen: null
    property string targetAddress: ""
    readonly property var apps: MediaState.apps
    readonly property var app: apps.find(candidate => candidate.id === appId) || null
    readonly property var windows: app ? MediaState.matches(app) : []
    readonly property var target: windows.find(window => window.address === targetAddress) || windows[0] || null
    function close() { mode = ""; appId = ""; targetAddress = "" }
    function open(app, kind, output) {
        if (!app) return
        if (kind !== "preview") {
            ControlState.close(); LauncherState.close(); NotificationState.close(); DashboardState.close(); MediaState.close(); WindowState.close()
        }
        screen = output; appId = app.id; mode = kind
    }
    function click(app, output) {
        const matches = MediaState.matches(app)
        if (matches.length > 1) open(app, "choose", output)
        else { close(); MediaState.activate(app) }
    }
    function act(operation) {
        const selectedApp = app, selectedWindow = target
        if (!selectedApp) return
        if (operation === "pin" || operation === "unpin") LauncherState.dockAction(operation, selectedApp.id)
        else if (operation === "new") LauncherState.launch(selectedApp.id,true)
        else if (selectedWindow) WindowState.perform(operation, selectedWindow.address)
        close()
    }
    Connections { target: ControlState; function onOpenedChanged() { if (ControlState.opened) root.close() } }
    Connections { target: LauncherState; function onOpenedChanged() { if (LauncherState.opened) root.close() } }
    Connections { target: NotificationState; function onOpenedChanged() { if (NotificationState.opened) root.close() } }
    Connections { target: DashboardState; function onOpenedChanged() { if (DashboardState.opened) root.close() } }
    Connections { target: MediaState; function onOpenedChanged() { if (MediaState.opened) root.close() } }
    Connections { target: WindowState; function onShowing() { root.close() } }
    Connections { target: Quickshell; function onScreensChanged() { if (Quickshell.screens.indexOf(root.screen) < 0) root.close() } }
    onAppChanged: if (!app && mode) close()
}
