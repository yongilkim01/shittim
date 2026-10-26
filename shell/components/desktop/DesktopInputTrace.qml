import QtQuick

// Read-only, bounded trace: no keys, file names, app titles, or pointer coordinates.
QtObject {
    id: root
    property bool enabled: false
    property bool requested: false
    property bool grabbed: false
    property bool windowActive: false
    property bool viewFocused: false
    property var events: []
    property double started: 0
    onEnabledChanged: {
        if (enabled) { events=[]; started=Date.now(); record("start") }
    }
    onRequestedChanged: record("request")
    onGrabbedChanged: record("grab")
    onWindowActiveChanged: record("keyboard")
    onViewFocusedChanged: record("view")
    function state() {
        return {requested:requested, grabbed:grabbed, windowActive:windowActive, viewFocused:viewFocused}
    }
    function record(event) {
        if (!enabled) return
        events=events.slice(-63).concat([Object.assign({event:event,ms:Math.max(0,Date.now()-started)},state())])
    }
    function snapshot() { return Object.assign({events:events},state()) }
}
