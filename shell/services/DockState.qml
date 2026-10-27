pragma Singleton
import QtQuick
import Quickshell
import "../core"

Scope {
    id: root
    property string appId: ""
    property string mode: ""
    readonly property var screen: session.screen
    readonly property alias panelSession: session
    PanelSession {
        id:session;coordinator:InteractionState;name:"dock"
        onRevoked:root.reset()
    }
    property string targetAddress: ""
    readonly property var apps: ApplicationsState.apps
    readonly property var app: apps.find(candidate => candidate.id === appId) || null
    readonly property var windows: app ? ApplicationsState.matches(app) : []
    readonly property var target: windows.find(window => window.address === targetAddress) || windows[0] || null
    function reset() { mode = ""; appId = ""; targetAddress = "" }
    function close() { session.close();reset() }
    function open(app, kind, output) {
        if (!app) return
        if(kind==="preview" && InteractionState.owner && InteractionState.owner!==session)return
        session.kind=kind==="preview" ? "preview" : "panel";session.keyboard=kind!=="preview"
        if(!session.open(output))return
        appId = app.id; mode = kind
    }
    function click(app, output) {
        const matches = ApplicationsState.matches(app)
        if (matches.length > 1) open(app, "choose", output)
        else { close(); ApplicationsState.activate(app) }
    }
    function act(operation) {
        const selectedApp = app, selectedWindow = target
        if (!selectedApp) return
        if (operation === "pin" || operation === "unpin") LauncherState.dockAction(operation, selectedApp.id)
        else if (operation === "new") LauncherState.launch(selectedApp.id,true)
        else if (selectedWindow) WindowState.perform(operation, selectedWindow.address)
        close()
    }
    onAppChanged: if (!app && mode) close()
}
