import QtQuick
import Quickshell
import "./components"
import "./services"

// Use the production config root. No window is mapped and no app is launched.
ShellRoot {
    id: root
    AppLauncher { visible: false }
    function finishIfReady() {
        if (LauncherState.ready) {
            console.info("[Shittim] 실제 GIO 앱 목록 확인: " + LauncherState.model.applications.length)
            Qt.callLater(() => Qt.quit())
        }
    }
    Component.onCompleted: finishIfReady()
    Connections { target: LauncherState; function onReadyChanged() { root.finishIfReady() } }
    Timer {
        interval: 12000; running: true
        onTriggered: { console.error("[Shittim] " + LauncherState.error); Qt.exit(1) }
    }
}
