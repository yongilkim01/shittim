pragma Singleton
import QtQuick
import Quickshell
import "../core/ActionErrors.js" as Errors

Scope {
    id:root
    property string selectedBacklight:""
    property string operationError:""
    property var queued:null
    readonly property var backlights:SystemBackend.state.backlights || []
    readonly property var backlight:backlights.find(device=>device.name===selectedBacklight) || backlights[0] || null
    readonly property bool ready:SystemBackend.ready
    readonly property bool busy:Object.values(SystemBackend.pending).some(request=>request.operation==="brightness")
    readonly property string error:operationError || SystemBackend.error
    function retain(consumer){SystemBackend.retain(consumer)}
    function release(consumer){SystemBackend.release(consumer)}
    function refresh(){operationError="";SystemBackend.refresh()}
    function setBrightness(value) {
        if(!ready || !backlight || !backlight.writable || !isFinite(value))return
        const message={action:"brightness",device:backlight.name,value:Math.max(0,Math.min(1,value))}
        if(busy){queued=message;return}
        operationError="";SystemBackend.send(message)
    }
    Connections {
        target:SystemBackend
        function onCompleted(result) {
            if(result.operation!=="brightness")return
            root.operationError=result.ok ? "" : Errors.message(result.code)
            const queued=root.queued;root.queued=null
            if(result.ok && queued && root.backlight && queued.device===root.backlight.name)SystemBackend.send(queued)
        }
    }
}
