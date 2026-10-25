import QtQuick
import "../../ui"

Canvas {
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"), w = width - 0.5, h = height - 0.5, cut = 7
        c.clearRect(0, 0, width, height)
        c.beginPath()
        c.moveTo(cut, 0.5); c.lineTo(w - cut, 0.5); c.lineTo(w, cut)
        c.lineTo(w, h - cut); c.lineTo(w - cut, h); c.lineTo(cut, h)
        c.lineTo(0.5, h - cut); c.lineTo(0.5, cut); c.closePath()
        c.fillStyle = Theme.floatingSurface; c.fill()
        c.lineWidth = 1; c.strokeStyle = Theme.accentDim; c.stroke()
        c.beginPath()
        c.moveTo(10.5, 10); c.lineTo(10.5, h - 10)
        c.moveTo(w - 10, 10); c.lineTo(w - 10, h - 10)
        c.strokeStyle = Theme.border; c.stroke()
    }
}
