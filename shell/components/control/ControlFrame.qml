import QtQuick
import "../../ui"

// Control-level HudFrame with the original top-right/bottom-left cut. Set `level` for heavier surfaces.
HudFrame {
	property real cut: 8
	level: "control"
	cutTopLeft: 0; cutTopRight: cut; cutBottomRight: 0; cutBottomLeft: cut
	fillColor: Theme.background
	strokeColor: active ? Theme.accent : Theme.border
}
