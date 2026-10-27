pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "../core"
import "../core/ActionErrors.js" as Errors

Scope {
    id:root
    property var selectedAdapter:null
    property var scanAdapter:null
    property string operationError:""
    readonly property var adapters:Bluetooth.adapters.values
    readonly property BluetoothAdapter adapter:adapters.indexOf(selectedAdapter)>=0 ? selectedAdapter : Bluetooth.defaultAdapter
    readonly property var devices:adapter===null ? [] : adapter.devices.values.slice().sort((a,b)=>Number(b.connected)-Number(a.connected) || Number(b.paired)-Number(a.paired) || a.name.localeCompare(b.name))
    readonly property bool ready:SystemBackend.ready
    readonly property bool bluetoothReady:SystemBackend.state.bluetooth===true
    readonly property var prompt:SystemBackend.prompt
    readonly property bool busy:Object.values(SystemBackend.pending).some(request=>["pair","connect","disconnect","cancel-pair"].indexOf(request.operation)>=0)
    readonly property string error:operationError || SystemBackend.error
    ConsumerSet {id:consumers;onActiveChanged:if(!active)root.stopDiscovery()}
    function retain(consumer){consumers.retain(consumer);SystemBackend.retain(consumer)}
    function release(consumer){consumers.release(consumer);SystemBackend.release(consumer)}
    function refresh(){operationError="";SystemBackend.refresh()}
    function toggleBluetooth(){if(adapter){operationError="";adapter.enabled=!adapter.enabled}}
    function searchBluetooth(){if(!adapter || !adapter.enabled)return;if(scanAdapter)scanAdapter.discovering=false;scanAdapter=adapter;adapter.discovering=true;scanTimeout.restart()}
    function stopDiscovery(){scanTimeout.stop();if(scanAdapter)scanAdapter.discovering=false;scanAdapter=null}
    function deviceAction(device){if(!ready || !bluetoothReady || busy || !device)return;operationError="";SystemBackend.send({action:device.connected ? "disconnect" : device.paired ? "connect" : "pair",device:device.dbusPath},45000)}
    function answerPrompt(accept,value){SystemBackend.answer(accept,value)}
    function cancelPair(){const current=prompt;if(current){SystemBackend.answer(false,"");if(current.device)SystemBackend.send({action:"cancel-pair",device:current.device})}}
    Timer {id:scanTimeout;interval:45000;onTriggered:root.stopDiscovery()}
    Connections {
        target:SystemBackend
        function onCompleted(result){
            if(["pair","connect","disconnect","cancel-pair"].indexOf(result.operation)<0)return
            root.operationError=result.ok ? "" : Errors.message(result.code)
            if(result.ok && result.operation==="pair")SystemBackend.send({action:"connect",device:result.target})
        }
    }
}
