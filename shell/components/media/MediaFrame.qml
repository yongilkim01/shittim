import QtQuick
import "../../ui"
import "../control"

ControlFrame {
    cut: 4
    strokeColor: Theme.border
    Rectangle { x: 1; y: 0; width: 15; height: 1; color: Theme.accentDim }
    Rectangle { x: 0; y: 1; width: 1; height: 13; color: Theme.accentDim }
    Rectangle { x: parent.width - 17; y: parent.height - 1; width: 16; height: 1; color: Theme.accentDim }
    Rectangle { x: parent.width - 1; y: parent.height - 14; width: 1; height: 13; color: Theme.accentDim }
    Rectangle { x: 17; y: 0; width: 7; height: 1; color: Theme.border }
    Rectangle { x: parent.width - 24; y: parent.height - 1; width: 6; height: 1; color: Theme.border }
}
