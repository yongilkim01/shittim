import QtQuick
import "../../ui"

// Floating dock: four cut corners, dim corner accents and a halo; inner rails mark the scroll area ends.
HudFrame {
    id: root
    level: "panel"
    glow: true
    cutTopLeft: 7; cutTopRight: 7; cutBottomRight: 7; cutBottomLeft: 7
    fillColor: Theme.floatingSurface
    strokeColor: Theme.accentDim
    accentColor: Theme.accentDim
    accentLength: Theme.cardAccent
    Rectangle { x: 16; y: 12; width: 1; height: root.height - 24; color: Theme.border }
    Rectangle { x: root.width - 12; y: 12; width: 1; height: root.height - 24; color: Theme.border }
}
