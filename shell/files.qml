//@ pragma AppId org.shittim.Files
//@ pragma ShellId shittim-files
//@ pragma IconTheme Shittim-HUD
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./components/files"
import "./ui/AssetPaths.js" as AssetPaths
import "./core"
import "./core/WindowData.js" as WindowData

ShellRoot {
    id: root
    property bool ready: false
    property var queued: []
    readonly property var ownWindow: Hyprland.toplevels.values.find(candidate=>Number(candidate.lastIpcObject.pid)===Quickshell.processId) || null
    function send(action:string, values:var):void {
        const message=JSON.stringify(Object.assign({action:action},values))+"\n"
        if (ready) backend.write(message)
        else if(action==="browse" && queued.length<32){
            queued=queued.concat([message])
            if(!backend.running){backend.running=true;startup.restart()}
        } else filesModel.accept({event:"error",tab:values.tab,request:values.request,error:"BackendUnavailable"})
    }
    function windowAction(action) {
        const target=root.ownWindow
        if (!target && action==="activate") { window.requestActivate(); Hyprland.refreshToplevels(); return }
        if (!target || control.busy) { filesModel.error="창 상태가 아직 준비되지 않았습니다. 잠시 후 다시 시도하세요."; return }
        control.submit(action,target.address)
    }
    function icon(entry) {
        if(entry.iconFile && entry.iconFile.indexOf("file:")===0) return entry.iconFile
        const names=entry.icons || []
        const places=["folder","folder-open","folder-documents","folder-download","folder-music","folder-pictures","folder-videos","folder-templates","folder-publicshare","folder-projects","user-desktop","user-home","user-trash"]
        const types=["text-x-generic","application-pdf","image-x-generic","audio-x-generic","video-x-generic"]
        for(const name of names) {
            if(places.indexOf(name)>=0) return AssetPaths.asset(Quickshell.shellDir,"icons/Shittim-HUD/scalable/places/"+name+".svg")
            if(types.indexOf(name)>=0) return AssetPaths.asset(Quickshell.shellDir,"icons/Shittim-HUD/scalable/mimetypes/"+name+".svg")
        }
        if(entry.directory) return AssetPaths.asset(Quickshell.shellDir,"icons/Shittim-HUD/scalable/places/folder.svg")
        for(const name of names) { const value=Quickshell.iconPath(name,true); if(value) return value }
        return AssetPaths.asset(Quickshell.shellDir,"icons/Shittim-HUD/scalable/mimetypes/text-x-generic.svg")
    }
    FilesModel { id:filesModel;onRequested:(action,values)=>root.send(action,values);onCloseRequested:window.close() }
    Process {
        id:backend;running:true;stdinEnabled:true
        command:["python3","-u",Quickshell.shellDir+"/../scripts/files-service.py"]
        stdout:SplitParser {onRead:data=>{
            try {
                const result=JSON.parse(data);filesModel.accept(result)
                if(result.event==="ready") {
                    startup.stop()
                    root.ready=true;for(const message of root.queued)backend.write(message);root.queued=[]
                    if(filesModel.tabs.length===0)filesModel.open(result.home,false)
                }
                if(result.event==="changed")refresh.restart()
            } catch(_) {filesModel.failRequests("InvalidResponse");filesModel.error="파일 응답을 읽지 못했습니다. F5로 다시 조회하세요."}
        }}
        onExited:{startup.stop();root.ready=false;root.queued=[];filesModel.failRequests("BackendExited");filesModel.error="파일 서비스가 종료되었습니다. F5로 다시 연결하세요."}
    }
    Timer {id:startup;running:true;interval:10000;onTriggered:{root.queued=[];filesModel.failRequests("RequestTimeout");backend.running=false}}
    Timer { id:refresh;interval:180;onTriggered:{if(filesModel.current && filesModel.current.dirty && !filesModel.busy)filesModel.refresh();else if(filesModel.current && filesModel.current.dirty)restart()} }
    Timer { id:windowRefresh;interval:60;onTriggered:Hyprland.refreshToplevels() }
    Component.onCompleted:Hyprland.refreshToplevels()
    Connections {
        target:Hyprland
        function onRawEvent(event) { if(["fullscreen","openwindow","closewindow","movewindow","movewindowv2","activewindowv2"].indexOf(event.name)>=0 || (event.name==="custom" && event.data.indexOf("shittim-window-state,")===0))windowRefresh.restart() }
    }
    WindowClient {
        id:control
        onFinished:result=>{windowRefresh.restart();if(!result.ok)filesModel.error=control.error}
    }
    FilesWindow {
        id:window;browserModel:filesModel;iconSource:root.icon
        controlBusy:control.busy
        managedMaximize:true
        maximized:root.ownWindow!==null && WindowData.maximized(root.ownWindow.lastIpcObject)
        onMinimizeRequested:root.windowAction("hide")
        onMaximizeRequested:root.windowAction("maximize")
        onClosing:Qt.quit()
    }
    IpcHandler {
        target:"files"
        function ping():string{return "ready"}
        function status():string{return JSON.stringify({ready:root.ready,tabs:filesModel.tabs.length,busy:filesModel.busy,
            windowBusy:control.busy,maximized:window.maximized,error:filesModel.error})}
        function open(payload:string):string {
            try {const request=JSON.parse(payload);if(typeof request.uri!=="string" || request.uri.length>16384)return "invalid";filesModel.open(request.uri,Boolean(request.newTab));window.show();root.windowAction("activate");return "requested"}catch(_){return "invalid"}
        }
    }
}
