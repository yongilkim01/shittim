import QtQuick
import "../../ui"

Item {
    id: root
    property string title: ""
    property string display: "N/A"
    property string detail: ""
    property real value: -1
    property bool warning: false
    // "42°C" -> "42" + "°C"; anything without a leading number stays whole.
    readonly property var parts: /^(-?[\d.]+)(.*)$/.exec(display) || [display, display, ""]
    implicitWidth: 126; implicitHeight: 108
    Canvas {
        id: ring; x: 21; y: 2; width: 84; height: 84
        onPaint: {
            const c = getContext("2d"), center = width / 2, radius = center - 6, start = -Math.PI / 2
            const tone = root.warning ? Theme.warning : Theme.accent
            c.clearRect(0, 0, width, height)
            // Track and the four quarter notches.
            c.lineWidth = 5; c.strokeStyle = Theme.trackFill
            c.beginPath(); c.arc(center, center, radius, 0, Math.PI * 2); c.stroke()
            c.lineWidth = 1; c.strokeStyle = Theme.border
            for (let i = 0; i < 4; i++) {
                const angle = start + i * Math.PI / 2, inner = radius - 5, outer = radius + 5
                c.beginPath(); c.moveTo(center + Math.cos(angle) * inner, center + Math.sin(angle) * inner)
                c.lineTo(center + Math.cos(angle) * outer, center + Math.sin(angle) * outer); c.stroke()
            }
            // Inner hairline.
            c.strokeStyle = Theme.frameLine
            c.beginPath(); c.arc(center, center, radius - 8, 0, Math.PI * 2); c.stroke()
            if (root.value >= 0) {
                const end = start + Math.PI * 2 * Math.max(0, Math.min(1, root.value))
                c.lineCap = "butt"
                c.lineWidth = 9; c.strokeStyle = Theme.accentGlow; c.globalAlpha = root.warning ? 0.25 : 0.35
                c.beginPath(); c.arc(center, center, radius, start, end); c.stroke()
                c.globalAlpha = 1; c.lineWidth = 5; c.strokeStyle = tone
                c.beginPath(); c.arc(center, center, radius, start, end); c.stroke()
                // Bright leading edge.
                c.lineWidth = 2; c.strokeStyle = Theme.textPrimary
                c.beginPath(); c.moveTo(center + Math.cos(end) * (radius - 3), center + Math.sin(end) * (radius - 3))
                c.lineTo(center + Math.cos(end) * (radius + 3), center + Math.sin(end) * (radius + 3)); c.stroke()
            }
        }
    }
    onValueChanged: ring.requestPaint()
    onWarningChanged: ring.requestPaint()
    HudText { x: 21; y: 24; width: 84; height: 14; horizontalAlignment: Text.AlignHCenter; text: root.title; font.pixelSize: 10; font.letterSpacing: 1; color: Theme.accent }
    Row {
        objectName: "gaugeValue"
        anchors.horizontalCenter: ring.horizontalCenter; y: 38
        HudText { text: root.parts[1]; font.pixelSize: 18; font.bold: true; color: root.warning ? Theme.warning : Theme.textPrimary }
        HudText { anchors.baseline: parent.children[0].baseline; text: root.parts[2]; font.pixelSize: 10; color: root.warning ? Theme.warning : Theme.textSecondary }
    }
    HudText { x: 0; y: 88; width: 126; height: 18; horizontalAlignment: Text.AlignHCenter; text: root.detail || "N/A"; font.pixelSize: Theme.textCaption; color: Theme.textSecondary; elide: Text.ElideRight }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    HudToolTip { visible: hover.containsMouse && root.detail.length > 0; text: root.detail }
}
