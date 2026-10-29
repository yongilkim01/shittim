import QtQuick
import "../../ui"

// Floating block of the media popup: the player (larger cut) is a panel, the web-app strip a card.
HudFrame {
    property real cut: Theme.panelCut
    level: cut >= 8 ? "panel" : "card"
    glow: true
    cutTopLeft: cut; cutTopRight: 0; cutBottomRight: cut; cutBottomLeft: 0
}
