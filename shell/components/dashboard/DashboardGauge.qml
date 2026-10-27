import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"

Item {
    id: root
    property string title: ""
    property string display: "N/A"
    property string detail: ""
    property real value: -1
    property bool warning: false
    implicitWidth: 126; implicitHeight: 108
    Canvas {
        id: ring; x: 25; y: 6; width: 76; height: 76
        onPaint: {
            const c = getContext("2d"), center = width / 2, radius = center - 3, start = -Math.PI / 2
            c.clearRect(0, 0, width, height)
            c.lineWidth = 5; c.strokeStyle = Theme.border
            for (let i = 0; i < 4; i++) {
                c.beginPath(); c.arc(center, center, radius, start + i * Math.PI / 2 + 0.025, start + (i + 1) * Math.PI / 2 - 0.025); c.stroke()
            }
            if (root.value >= 0) {
                c.strokeStyle = root.warning ? Theme.warning : Theme.accent
                c.beginPath(); c.arc(center, center, radius, start, start + Math.PI * 2 * Math.max(0, Math.min(1, root.value))); c.stroke()
            }
        }
    }
    onValueChanged: ring.requestPaint()
    onWarningChanged: ring.requestPaint()
    HudText { x: 25; y: 23; width: 76; height: 17; horizontalAlignment: Text.AlignHCenter; text: root.title; font.pixelSize: 10; color: Theme.accent }
    HudText { objectName: "gaugeValue"; x: 25; y: 39; width: 76; height: 22; horizontalAlignment: Text.AlignHCenter; text: root.display; font.pixelSize: 14; color: root.warning ? Theme.warning : Theme.textPrimary }
    HudText { x: 0; y: 86; width: 126; height: 18; horizontalAlignment: Text.AlignHCenter; text: root.detail || "N/A"; font.pixelSize: Theme.textCaption; color: Theme.textSecondary }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    Controls.ToolTip.visible: hover.containsMouse && root.detail.length > 0
    Controls.ToolTip.text: root.detail
}
