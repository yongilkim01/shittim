pragma Singleton
import Quickshell

Scope {
    readonly property int cpu:SystemBackend.state.cpu===undefined ? -1 : SystemBackend.state.cpu
    readonly property int memory:SystemBackend.state.memory===undefined ? -1 : SystemBackend.state.memory
    readonly property int uptime:SystemBackend.state.uptime || 0
    readonly property bool ready:SystemBackend.ready
    readonly property string error:SystemBackend.error
    function retain(consumer){SystemBackend.retain(consumer)}
    function release(consumer){SystemBackend.release(consumer)}
    function refresh(){SystemBackend.refresh()}
}
