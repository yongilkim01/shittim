import QtQuick

// Bevelled HUD frame with a pointer toward the item it describes. Floating layer: a faint outer glow
// and bright accents on the top-left and bottom-right bevels set it above the surface it covers.
Item {
	id: root
	property string arrow: "top"   // "top" | "bottom" | "none"
	property real arrowX: width / 2
	property real arrowSize: 9
	property real cut: 10
	property real padding: Theme.spaceM
	property color fillColor: Theme.floatingSurface
	property color strokeColor: Theme.accentDim
	default property alias content: body.data
	readonly property real arrowSpace: arrow === "none" ? 0 : arrowSize
	implicitWidth: body.childrenRect.width + padding * 2
	implicitHeight: body.childrenRect.height + padding * 2 + arrowSpace
	Canvas {
		id: canvas; anchors.fill: parent
		onWidthChanged: requestPaint(); onHeightChanged: requestPaint()
		onPaint: {
			const c = getContext("2d"), d = root.cut, a = root.arrowSize
			const top = (root.arrow === "top" ? a : 0) + 1.5, bottom = height - (root.arrow === "bottom" ? a : 0) - 1.5
			const left = 1.5, right = width - 1.5
			const ax = Math.max(left + d + a, Math.min(right - d - a, root.arrowX))
			c.clearRect(0, 0, width, height)
			c.beginPath()
			c.moveTo(left + d, top)
			if (root.arrow === "top") { c.lineTo(ax - a, top); c.lineTo(ax, top - a); c.lineTo(ax + a, top) }
			c.lineTo(right - d, top); c.lineTo(right, top + d); c.lineTo(right, bottom - d); c.lineTo(right - d, bottom)
			if (root.arrow === "bottom") { c.lineTo(ax + a, bottom); c.lineTo(ax, bottom + a); c.lineTo(ax - a, bottom) }
			c.lineTo(left + d, bottom); c.lineTo(left, bottom - d); c.lineTo(left, top + d); c.closePath()
			c.fillStyle = root.fillColor; c.fill()
			c.strokeStyle = Theme.accentGlow; c.globalAlpha = 0.35; c.lineWidth = 3; c.stroke()
			c.globalAlpha = 1; c.strokeStyle = root.strokeColor; c.lineWidth = 1; c.stroke()
			const e = Math.min(14, (right - left) / 4)
			c.strokeStyle = Theme.accent; c.lineWidth = 2
			c.beginPath(); c.moveTo(left, top + d + e); c.lineTo(left, top + d); c.lineTo(left + d, top); c.lineTo(left + d + e, top); c.stroke()
			c.beginPath(); c.moveTo(right, bottom - d - e); c.lineTo(right, bottom - d); c.lineTo(right - d, bottom); c.lineTo(right - d - e, bottom); c.stroke()
		}
	}
	onArrowChanged: canvas.requestPaint(); onArrowXChanged: canvas.requestPaint()
	onFillColorChanged: canvas.requestPaint(); onStrokeColorChanged: canvas.requestPaint()
	Item {
		id: body
		x: root.padding; y: root.padding + (root.arrow === "top" ? root.arrowSize : 0)
		width: root.width - root.padding * 2; height: childrenRect.height
	}
}
