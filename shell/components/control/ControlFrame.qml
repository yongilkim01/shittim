import QtQuick
import "../../ui"

Item {
	id: root
	property bool active: false
	property real cut: 8
	property color fillColor: Theme.background
	property color gradientColor: fillColor
	property color strokeColor: active ? Theme.accent : Theme.border
	Canvas {
		id: canvas
		anchors.fill: parent
		onWidthChanged: requestPaint()
		onHeightChanged: requestPaint()
		onPaint: {
			const c = getContext("2d"), w = width - 0.5, h = height - 0.5, d = root.cut
			c.clearRect(0, 0, width, height)
			c.beginPath()
			c.moveTo(0.5, 0.5); c.lineTo(w - d, 0.5); c.lineTo(w, d)
			c.lineTo(w, h); c.lineTo(d, h); c.lineTo(0.5, h - d); c.closePath()
			const gradient = c.createLinearGradient(0, 0, width, height)
			gradient.addColorStop(0, root.fillColor); gradient.addColorStop(1, root.gradientColor)
			c.fillStyle = gradient; c.fill()
			c.strokeStyle = root.strokeColor; c.lineWidth = 1; c.stroke()
		}
	}
	onFillColorChanged: canvas.requestPaint()
	onGradientColorChanged: canvas.requestPaint()
	onStrokeColorChanged: canvas.requestPaint()
	onCutChanged: canvas.requestPaint()
}
