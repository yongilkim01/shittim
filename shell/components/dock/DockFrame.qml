import QtQuick
import "../../ui"

Canvas {
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"), edge = 2.5, w = width - edge, h = height - edge, cut = 7
        c.clearRect(0, 0, width, height)
        c.beginPath()
        c.moveTo(edge + cut, edge); c.lineTo(w - cut, edge); c.lineTo(w, edge + cut)
        c.lineTo(w, h - cut); c.lineTo(w - cut, h); c.lineTo(edge + cut, h)
        c.lineTo(edge, h - cut); c.lineTo(edge, edge + cut); c.closePath()
        c.fillStyle = Theme.floatingSurface; c.fill()
        c.strokeStyle = Theme.accent
        c.globalAlpha = 0.06; c.lineWidth = 5; c.stroke()
        c.globalAlpha = 0.12; c.lineWidth = 3; c.stroke()
        c.globalAlpha = 1
        c.lineWidth = 1; c.strokeStyle = Theme.accentDim; c.stroke()
        c.beginPath()
        c.moveTo(16.5, 12); c.lineTo(16.5, h - 12)
        c.moveTo(w - 12, 12); c.lineTo(w - 12, h - 12)
        c.strokeStyle = Theme.border; c.stroke()
    }
}
