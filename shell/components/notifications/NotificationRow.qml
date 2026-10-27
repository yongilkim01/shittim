import QtQuick
import "../../ui"
import "NotificationData.js" as Data

FocusScope {
    id: root
    required property var entry
    property real now: Date.now()
    property bool expanded: false
    property bool popup: false
    readonly property bool hovered: mouse.containsMouse || closeMouse.containsMouse
    signal activated()
    signal dismissed()
    signal actionRequested(string actionId)
    implicitHeight: expanded ? 62 + detail.implicitHeight : 50
    activeFocusOnTab: true
    clip: true
    Rectangle {
        objectName: "notificationHover"
        x: 8; y: 2; width: Math.max(0, root.width - 16); height: Math.max(0, root.height - 4)
        color: Theme.surfaceElevated; opacity: root.hovered || root.activeFocus ? 0.6 : 0
    }
    MouseArea {
        id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: { root.forceActiveFocus(); root.activated() }
    }
    Keys.onReturnPressed: root.activated()
    Keys.onSpacePressed: root.activated()
    Image {
        id: appIcon; x: 28; y: 12; width: 21; height: 21
        source: root.entry.icon; sourceSize.width: 24; sourceSize.height: 24
        fillMode: Image.PreserveAspectFit; visible: status === Image.Ready
    }
    HudIcon { x: 28; y: 12; width: 21; height: 21; font.pixelSize: 22; text: root.entry.category === "system" ? "\uf108" : "\uf0f3"; visible: appIcon.status !== Image.Ready; color: root.entry.urgency === 2 ? Theme.warning : Theme.accentBright }
    Rectangle { x: 15; y: 21; width: 3; height: 3; visible: !root.entry.read; color: Theme.accent }
    HudText { objectName: "notificationSummary"; x: 68; y: 5; width: Math.max(0, root.width - x - 106); height: 18; text: root.entry.summary; font.pixelSize: 11; color: Theme.textPrimary }
    HudText { x: 68; y: 23; width: Math.max(0, root.width - x - 20); height: 17; text: root.entry.body; font.pixelSize: 10; color: Theme.accentDim }
    HudText { objectName: "notificationTime"; x: root.width - 98; y: 6; width: 60; height: 17; horizontalAlignment: Text.AlignRight; text: Data.relative(root.entry.received, root.now); font.pixelSize: Theme.textCaption; color: Theme.accentDim }
    HudText {
        objectName: "notificationClose"
        x: root.width - 28; y: 5; width: 20; height: 20; text: "×"; color: Theme.textSecondary; font.pixelSize: 14
        visible: root.hovered || root.activeFocus || root.popup
        MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.dismissed() }
    }
    Column {
        id: detail; x: 68; y: 47; width: Math.max(0, root.width - x - 20); spacing: 8; visible: root.expanded
        HudText { width: parent.width; height: implicitHeight; text: root.entry.summary; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 512; elide: Text.ElideNone }
        HudText { width: parent.width; height: implicitHeight; text: root.entry.body; font.pixelSize: 10; wrapMode: Text.Wrap; maximumLineCount: 8192; elide: Text.ElideNone; color: Theme.textSecondary }
        HudText { width: parent.width; height: 18; text: root.entry.appName + " · " + new Date(root.entry.received).toLocaleString(); font.pixelSize: Theme.textCaption; color: Theme.textMuted }
        Image {
            width: parent.width; height: visible ? Math.min(140, width) : 0
            source: root.expanded && root.entry.live ? root.entry.image : ""
            sourceSize.width: 256; sourceSize.height: 256
            fillMode: Image.PreserveAspectFit; visible: source.toString().length > 0 && status === Image.Ready
        }
        Flow {
            width: parent.width; spacing: 4
            Repeater {
                model: root.entry.live ? root.entry.actions : []
                HudButton {
                    required property var modelData
                    objectName: "notification-action-" + modelData.id
                    text: modelData.text || modelData.id
                    width: Math.min(detail.width, implicitWidth)
                    implicitHeight: 24
                    onClicked: root.actionRequested(modelData.id)
                }
            }
        }
    }
    Rectangle { x: 21; y: parent.height - 1; width: Math.max(0, parent.width - 42); height: 1; color: Theme.border; opacity: 0.3 }
}
