pragma Singleton
import QtQuick
import Quickshell
import "../core/ApplicationData.js" as Data

// Application catalogue/window matching is independent of MPRIS playback and panels.
Scope {
    id:root
    property string error:""
    property string pendingApp:""
    property int pendingWindow:0
    readonly property bool busy:ApplicationCatalog.launching || pendingWindow>0
    signal activating()
    signal activationFinished(bool ok)
    readonly property var windows:WindowCatalog.windows
    readonly property var apps: {
        const catalogue=ApplicationCatalog.applications, favorites=ApplicationCatalog.dockFavorites
        return favorites.map(id=>catalogue.find(app=>app.id===id)).filter(app=>app!==undefined)
            .concat(catalogue.filter(app=>favorites.indexOf(app.id)<0 && matches(app).length>0))
    }
    function matches(app) { return Data.matches(app,windows,ApplicationCatalog.applications,ApplicationCatalog.dockWindowClasses) }
    function running(app) { return matches(app).length>0 }
    function activate(app) {
        if(!app || busy)return false
        error=""
        if(!ApplicationCatalog.ready || !ApplicationCatalog.applications.some(candidate=>candidate.id===app.id)) {
            error="앱 목록이 변경되었습니다. F5로 새로고침하세요.";return false
        }
        const target=Data.preferred(matches(app),WindowCatalog.recent)[0]
        activating()
        if(target) {
            pendingWindow=WindowCommands.submit("activate",target.address)
            const accepted=pendingWindow>0
            if(!accepted)error=WindowCommands.error || "창을 활성화할 수 없습니다."
            return accepted
        }
        pendingApp=app.id;ApplicationCatalog.launch(app.id);return true
    }
    Connections {
        target:WindowCommands
        function onFinished(result){
            if(result.id!==root.pendingWindow)return
            root.pendingWindow=0;root.error=result.ok ? "" : WindowCommands.error;root.activationFinished(result.ok)
        }
    }
    Connections {
        target:ApplicationCatalog
        function onLaunchFinished(appId,ok) {
            if(appId!==root.pendingApp)return
            root.pendingApp="";root.error=ok ? "" : ApplicationCatalog.error;root.activationFinished(ok)
        }
    }
}
