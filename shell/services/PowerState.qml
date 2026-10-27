pragma Singleton
import QtQuick
import Quickshell
import "../core/ActionErrors.js" as Errors

Scope {
    id:root
    property string operationError:""
    readonly property var profiles:SystemBackend.state.profiles || []
    readonly property string profile:SystemBackend.state.profile || ""
    readonly property bool ready:SystemBackend.ready
    readonly property bool busy:Object.values(SystemBackend.pending).some(request=>request.operation==="profile")
    readonly property string error:operationError || SystemBackend.error
    function retain(consumer){SystemBackend.retain(consumer)}
    function release(consumer){SystemBackend.release(consumer)}
    function refresh(){operationError="";SystemBackend.refresh()}
    function setProfile(value){if(profiles.indexOf(value)>=0 && !busy)SystemBackend.send({action:"profile",profile:value})}
    Connections {target:SystemBackend;function onCompleted(result){if(result.operation==="profile")root.operationError=result.ok ? "" : Errors.message(result.code)}}
}
