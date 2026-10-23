import QtQuick
import "NotificationData.js" as Data

QtObject {
    id: root
    required property var notification
    required property var model
    required property var resolveIcon
    property bool ended: false
    property bool armed: false
    readonly property var snapshot: notification && !ended ? Data.snapshot(notification, resolveIcon) : null
    function update() { if (!ended && snapshot !== null) model.receive(Object.assign({}, snapshot, {restored: false})) }
    // Native replacements update properties on the existing object; they do not re-emit notification().
    onSnapshotChanged: if (armed) Qt.callLater(update)
    Component.onCompleted: armed = true
    property Connections events: Connections {
        target: root.notification
        function onClosed(reason) { root.ended = true; root.model.closed(root.notification.id, Number(reason)) }
    }
}
