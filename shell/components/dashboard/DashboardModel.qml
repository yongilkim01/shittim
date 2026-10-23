import QtQuick
import "Format.js" as Format

QtObject {
    id: root
    property bool ready: false
    property string error: ""
    property var snapshot: empty()
    property var samples: []
    function empty() { return Format.emptySnapshot() }
    function reset() { ready = false; error = ""; snapshot = empty(); samples = [] }
    function failure(message) { reset(); error = message }
    function receive(message) {
        if (message.event !== "sample") { failure("시스템 정보를 읽지 못했습니다."); return }
        const network = message.network
        if (network.interface !== snapshot.network.interface) samples = []
        samples = samples.concat([{time: message.time, down: network.down, up: network.up}]).slice(-60)
        snapshot = message
        ready = true; error = ""
    }
}
