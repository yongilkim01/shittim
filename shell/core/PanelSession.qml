import QtQuick

QtObject {
    id: root
    required property var coordinator
    property string kind: "panel"
    property string name: ""
    property bool keyboard: true
    property var anchorWindow: null
    property var anchorItem: null
    readonly property bool active: coordinator.owner === root
    readonly property var screen: active ? coordinator.screen : null
    signal revoked(string reason)
    function open(output, anchor, item) {
        anchorWindow=anchor || null; anchorItem=item || null
        return coordinator.acquire(root,output)
    }
    function close(reason) { coordinator.release(root,reason || "dismiss") }
    function containsAnchor(point) {
        if (!anchorItem) return false
        const origin=anchorItem.mapToItem(null,0,0)
        return point.x>=origin.x && point.x<=origin.x+anchorItem.width && point.y>=origin.y && point.y<=origin.y+anchorItem.height
    }
    Component.onDestruction: if (coordinator && typeof coordinator.forget==="function") coordinator.forget(root)
}
