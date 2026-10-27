import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"

Item {
    id: root
    property string icon: ""
    property string tooltipText: ""
    property bool framed: false
    property bool running: false
    property bool active: false
    property string imageSource: ""
    signal clicked()
    signal contextRequested()
    Keys.forwardTo:[input]
    implicitWidth: 30; implicitHeight: 28
    ControlFrame {
        anchors.fill: parent; cut: 2
        visible: root.framed || input.hovered || input.focused
        strokeColor: input.hovered || input.focused || root.active ? Theme.accent : Theme.border
        fillColor: input.hovered ? Theme.surfaceElevated : Theme.background
    }
    Image {
        id: image; anchors.centerIn: parent; width: 28; height: 28
        source: root.imageSource; asynchronous: true; fillMode: Image.PreserveAspectFit
        sourceSize.width: 56; sourceSize.height: 56
        visible: status === Image.Ready; opacity: root.enabled ? 1 : 0.4
    }
    HudIcon {
        anchors.centerIn: parent; text: root.icon; font.pixelSize: root.framed ? 24 : 26
        visible: image.status !== Image.Ready; color: root.enabled ? Theme.textPrimary : Theme.textMuted
    }
    Rectangle { visible: root.running; height: 2; width: 12; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 2; color: Theme.accent }
    ActionInput {id:input;label:root.tooltipText;contextEnabled:true;onTriggered:root.clicked();onContextRequested:root.contextRequested()}
}
