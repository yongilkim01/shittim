import QtQuick
import QtQuick.Shapes

// One frame for every HUD surface. `level` sets how much decoration a surface earns:
//   window  - outer shell: two cut corners, bright accents on all four corners, inner double line
//   panel   - main content block: asymmetric cuts, accents on the cut corners
//   card    - secondary block: small asymmetric cuts, short dim accents
//   control - buttons, tiles, rows: one small cut, no accents; state shows through stroke and fill
// Every corner can be overridden; content goes in as children and is not clipped.
Item {
	id: root
	property string level: "card"
	property bool active: false
	property bool hovered: false
	readonly property bool window: level === "window"
	readonly property bool panel: level === "panel"
	readonly property bool card: level === "card"
	readonly property real cut: window ? Theme.windowCut : panel ? Theme.panelCut : card ? Theme.cardCut : Theme.controlCut
	property real cutTopLeft: window ? 0 : (panel || card) ? cut : 0
	property real cutTopRight: window ? cut : (panel || card) ? 0 : cut
	property real cutBottomRight: window ? 0 : (panel || card) ? cut : 0
	property real cutBottomLeft: window ? cut : (panel || card) ? 0 : cut
	property color fillColor: window ? Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98) : panel ? Theme.background : Theme.surface
	property color gradientColor: fillColor
	property color strokeColor: active ? Theme.borderActive : hovered ? Theme.accentDim : Theme.border
	property real strokeWidth: Theme.lineWidth
	property real accentLength: window ? Theme.windowAccent : panel ? Theme.panelAccent : card ? Theme.cardAccent : 0
	property color accentColor: window || active ? Theme.accent : Theme.accentDim
	property real accentWidth: window || panel ? Theme.accentLineWidth : Theme.lineWidth
	// Corners carrying an accent: all four for the window, otherwise the cut ones.
	property var accentCorners: window ? [true, true, true, true]
		: [cutTopLeft > 0, cutTopRight > 0, cutBottomRight > 0, cutBottomLeft > 0]
	property real inset: window ? Theme.frameInset : 0
	property color innerColor: Theme.frameLine
	Behavior on strokeColor { ColorAnimation { duration: Theme.hoverDuration; easing.type: Theme.easing } }
	Behavior on accentColor { ColorAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }

	// Outline of a cut rectangle inset by `d`, as [x, y] points clockwise from the top-left.
	function outline(d) {
		const w = width - d, h = height - d, s = Math.max(0, d)
		const tl = Math.max(0, cutTopLeft - d * 0.4), tr = Math.max(0, cutTopRight - d * 0.4)
		const br = Math.max(0, cutBottomRight - d * 0.4), bl = Math.max(0, cutBottomLeft - d * 0.4)
		return [[s + tl, s], [w - tr, s], [w, s + tr], [w, h - br], [w - br, h], [s + bl, h], [s, h - bl], [s, s + tl]]
	}
	readonly property var points: width > 0 && height > 0 ? outline(strokeWidth / 2) : []
	readonly property var innerPoints: inset > 0 && width > inset * 4 && height > inset * 4 ? outline(inset + 0.5) : []
	// Accent polylines run `accentLength` along both edges of a corner, through its cut.
	readonly property var accents: {
		const p = points, a = accentLength, result = []
		if (p.length !== 8 || a <= 0) return result
		const len = (from, to) => Math.hypot(to[0] - from[0], to[1] - from[1])
		const toward = (from, to, distance) => { const l = len(from, to) || 1, t = Math.min(1, distance / l); return [from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t] }
		// Corner i spans points[2i - 1] (end of the previous edge) and points[2i] (start of the next edge).
		const corner = [[p[7], p[0], p[1], p[6]], [p[1], p[2], p[3], p[0]], [p[3], p[4], p[5], p[2]], [p[5], p[6], p[7], p[4]]]
		for (let i = 0; i < 4; ++i) {
			if (!accentCorners[i]) continue
			const [first, second, away, before] = corner[i]
			result.push([toward(first, before, a), first, second, toward(second, away, a)])
		}
		return result
	}

	Shape {
		anchors.fill: parent
		preferredRendererType: Shape.CurveRenderer
		ShapePath {
			strokeColor: root.strokeColor
			strokeWidth: root.strokeWidth
			joinStyle: ShapePath.MiterJoin
			fillGradient: LinearGradient {
				x1: 0; y1: 0; x2: root.width; y2: root.height
				GradientStop { position: 0; color: root.fillColor }
				GradientStop { position: 1; color: root.gradientColor }
			}
			PathPolyline { path: root.points.length ? root.points.concat([root.points[0]]).map(p => Qt.point(p[0], p[1])) : [] }
		}
		ShapePath {
			strokeColor: root.innerPoints.length ? root.innerColor : "transparent"
			strokeWidth: Theme.lineWidth
			fillColor: "transparent"
			PathPolyline { path: root.innerPoints.length ? root.innerPoints.concat([root.innerPoints[0]]).map(p => Qt.point(p[0], p[1])) : [] }
		}
		ShapePath {
			strokeColor: root.accents.length ? root.accentColor : "transparent"
			strokeWidth: root.accentWidth
			fillColor: "transparent"
			capStyle: ShapePath.FlatCap
			joinStyle: ShapePath.MiterJoin
			PathMultiline { paths: root.accents.map(line => line.map(p => Qt.point(p[0], p[1]))) }
		}
	}
}
