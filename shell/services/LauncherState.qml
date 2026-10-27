pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../components/launcher"
import "../core"

// Search/panel adapter. The catalogue and application process know no screen state.
Scope {
    id:root
    readonly property bool opened:session.active
    readonly property var targetScreen:session.screen
    readonly property alias panelSession:session
    readonly property alias model:search
    readonly property bool ready:ApplicationCatalog.ready
    readonly property bool launching:ApplicationCatalog.launching
    readonly property string error:ApplicationCatalog.error
    readonly property var dockFavorites:ApplicationCatalog.dockFavorites
    readonly property var dockWindowClasses:ApplicationCatalog.dockWindowClasses
    readonly property string dockError:ApplicationCatalog.dockError
    property var launchOwner:null
    property int launchGeneration:0
    property string launchAppId:""
    signal applicationLaunched()
    signal launchFinished(string appId,bool ok)
    PanelSession {id:session;coordinator:InteractionState;name:"launcher";onRevoked:search.reset()}
    LauncherModel {id:search;applications:ApplicationCatalog.applications}
    function show(){
        if(opened)return
        const output=InteractionState.screenFor(null)
        if(!output)return
        search.reset();ApplicationCatalog.clearError();session.open(output);ApplicationCatalog.ensure()
    }
    function close(){session.close();search.reset()}
    function toggle(){if(opened)close();else show()}
    function refresh(){ApplicationCatalog.refresh()}
    function dockAction(action,appId,index){ApplicationCatalog.dockAction(action,appId,index)}
    function assetSource(relative){return ApplicationCatalog.assetSource(relative)}
    function iconSource(app){return ApplicationCatalog.iconSource(app)}
    function launch(appId,newWindow){
        if(!ApplicationCatalog.launch(appId,newWindow))return false
        launchOwner=InteractionState.owner;launchGeneration=InteractionState.generation;launchAppId=appId;return true
    }
    Connections {
        target:ApplicationCatalog
        function onLaunchFinished(appId,ok){
            if(appId!==root.launchAppId)return
            if(ok){
                root.applicationLaunched()
                if(InteractionState.owner===root.launchOwner && InteractionState.generation===root.launchGeneration)InteractionState.dismiss("action")
            }
            root.launchAppId="";root.launchOwner=null;root.launchFinished(appId,ok)
        }
    }
    IpcHandler {
        target:"launcher"
        function toggle():void{root.toggle()}
        function show():void{root.show()}
        function hide():void{root.close()}
        function reload():void{root.refresh()}
        function status():string{return JSON.stringify({opened:root.opened,ready:root.ready,applications:ApplicationCatalog.applications.length,launching:root.launching})}
    }
}
