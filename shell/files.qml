//@ pragma AppId org.shittim.Files
//@ pragma ShellId shittim-files
//@ pragma IconTheme Shittim-HUD
import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "./components/files"

ShellRoot {
    id: root
    property bool ready: false
    property var queued: []
    function send(action, values) {
        const message=JSON.stringify(Object.assign({action:action},values))+"\n"
        if (ready) backend.write(message)
        else queued=queued.concat([message])
    }
    function windowAction(action) {
        const target=Hyprland.toplevels.values.find(window=>Number(window.lastIpcObject.pid)===Quickshell.processId)
        if (!target && action==="activate") { window.requestActivate(); Hyprland.refreshToplevels(); return }
        if (!target || control.running) { filesModel.error="창 상태가 아직 준비되지 않았습니다. 잠시 후 다시 시도하세요."; return }
        control.command=["python3",Quickshell.shellDir+"/../scripts/window-service.py",action,target.address]
        control.running=true
    }
    function icon(entry) {
        if(entry.iconFile && entry.iconFile.indexOf("file:")===0) return entry.iconFile
        const names=entry.icons || []
        const places=["folder","folder-open","folder-documents","folder-download","folder-music","folder-pictures","folder-videos","folder-templates","folder-publicshare","user-desktop","user-home","user-trash"]
        const types=["text-x-generic","application-pdf","image-x-generic","audio-x-generic","video-x-generic"]
        for(const name of names) {
            if(places.indexOf(name)>=0) return Qt.resolvedUrl("../assets/icons/Shittim-HUD/scalable/places/"+name+".svg")
            if(types.indexOf(name)>=0) return Qt.resolvedUrl("../assets/icons/Shittim-HUD/scalable/mimetypes/"+name+".svg")
        }
        if(entry.directory) return Qt.resolvedUrl("../assets/icons/Shittim-HUD/scalable/places/folder.svg")
        for(const name of names) { const value=Quickshell.iconPath(name,true); if(value) return value }
        return Qt.resolvedUrl("../assets/icons/Shittim-HUD/scalable/mimetypes/text-x-generic.svg")
    }
    FilesModel { id:filesModel;onRequested:(action,values)=>root.send(action,values);onCloseRequested:window.close() }
    Process {
        id:backend;running:true;stdinEnabled:true
        command:["python3","-u",Quickshell.shellDir+"/../scripts/files-service.py"]
        stdout:SplitParser {onRead:data=>{
            try {
                const result=JSON.parse(data);filesModel.accept(result)
                if(result.event==="ready") {
                    root.ready=true;for(const message of root.queued)backend.write(message);root.queued=[]
                    if(filesModel.tabs.length===0)filesModel.open(result.home,false)
                }
                if(result.event==="changed")refresh.restart()
            } catch(_) {filesModel.error="파일 응답을 읽지 못했습니다."}
        }}
        onExited:{root.ready=false;filesModel.error="파일 서비스가 종료되었습니다. 창을 닫고 다시 여세요."}
    }
    Timer { id:refresh;interval:180;onTriggered:{if(filesModel.current && filesModel.current.dirty && !filesModel.busy)filesModel.refresh();else if(filesModel.current && filesModel.current.dirty)restart()} }
    Process {id:control;stdout:SplitParser{onRead:data=>{try{const result=JSON.parse(data);if(!result.ok)filesModel.error="창 제어 실패: "+result.error}catch(_){}}}}
    Window {
        id:window;visible:true;title:(filesModel.current ? filesModel.current.name+" — " : "")+"Shittim Files"
        flags:Qt.Window|Qt.FramelessWindowHint|Qt.NoDropShadowWindowHint;color:"transparent"
        width:Math.min(Screen.desktopAvailableWidth-24,Math.max(440,Math.min(860,Screen.width*0.34)))
        height:Math.min(Screen.desktopAvailableHeight-32,width*326/440)
        minimumWidth:Math.min(400,Screen.desktopAvailableWidth-24);minimumHeight:Math.min(280,Screen.desktopAvailableHeight-32)
        onClosing:Qt.quit()
        FilesView {
            id:view;anchors.fill:parent;model:filesModel;iconSource:root.icon;maximized:window.visibility===Window.Maximized;focus:true
            onDragRequested:window.startSystemMove()
            onMinimizeRequested:root.windowAction("hide")
            onMaximizeRequested:{if(window.visibility===Window.Maximized)window.showNormal();else window.showMaximized()}
            onCloseRequested:window.close()
        }
        Repeater {
            model:[Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.LeftEdge|Qt.TopEdge,Qt.RightEdge|Qt.TopEdge,Qt.LeftEdge|Qt.BottomEdge,Qt.RightEdge|Qt.BottomEdge]
            delegate:MouseArea {
                required property int modelData
                readonly property bool left:Boolean(modelData & Qt.LeftEdge)
                readonly property bool right:Boolean(modelData & Qt.RightEdge)
                readonly property bool top:Boolean(modelData & Qt.TopEdge)
                readonly property bool bottom:Boolean(modelData & Qt.BottomEdge)
                x:left ? 0 : right ? window.width-5 : 5;y:top ? 0 : bottom ? window.height-5 : 5
                width:left||right ? 5 : window.width-10;height:top||bottom ? 5 : window.height-10
                enabled:window.visibility!==Window.Maximized;z:100
                cursorShape:(left||right)&&(top||bottom) ? (left===top ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : left||right ? Qt.SizeHorCursor : Qt.SizeVerCursor
                onPressed:window.startSystemResize(modelData)
            }
        }
    }
    IpcHandler {
        target:"files"
        function ping():string{return "ready"}
        function status():string{return JSON.stringify({ready:root.ready,tabs:filesModel.tabs.length,busy:filesModel.busy,error:filesModel.error})}
        function open(payload:string):string {
            try {const request=JSON.parse(payload);if(typeof request.uri!=="string" || request.uri.length>16384)return "invalid";filesModel.open(request.uri,Boolean(request.newTab));window.show();root.windowAction("activate");return "requested"}catch(_){return "invalid"}
        }
    }
}
