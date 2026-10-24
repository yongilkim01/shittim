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
    implicitWidth: 30; implicitHeight: 28
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: tooltipText
    Accessible.onPressAction: if (enabled) clicked()
    Keys.onReturnPressed: if (enabled) clicked()
    Keys.onSpacePressed: if (enabled) clicked()
    ControlFrame {
        anchors.fill: parent; cut: 2
        visible: root.framed || mouse.containsMouse || root.activeFocus
        strokeColor: mouse.containsMouse || root.activeFocus || root.active ? Theme.accent : Theme.border
        fillColor: mouse.containsMouse ? Theme.surfaceElevated : Theme.background
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
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => { if (event.button === Qt.RightButton) root.contextRequested(); else root.clicked() } }
    Controls.ToolTip {
        visible: mouse.containsMouse && root.tooltipText.length > 0; delay: 450
        contentItem: HudText { text: root.tooltipText; font.pixelSize: 10; maximumLineCount: 4; wrapMode: Text.Wrap; width: Math.min(280, implicitWidth) }
        background: Rectangle { color: Theme.background; border.color: Theme.border }
    }
}
