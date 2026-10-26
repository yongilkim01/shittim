import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"

Item {
    id: root
    property string glyph: "folder"
    property string hint: ""
    property bool active: false
    property bool windowControl: false
    property color ink: Theme.accent
    signal clicked()
    implicitWidth: 24; implicitHeight: 22
    Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 2; color: root.active ? "#063441" : mouse.containsMouse ? Theme.surfaceElevated : "transparent"; border.width: 1; border.color: root.active || mouse.containsMouse ? Theme.border : "transparent" }
    FileGlyph { anchors.centerIn: parent; width: root.windowControl ? 18 : 14; height: width; windowControl: root.windowControl; glyph: root.glyph; ink: root.enabled ? root.ink : Theme.textMuted }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.clicked() }
    Controls.ToolTip { visible: mouse.containsMouse && root.hint.length>0; text: root.hint; delay: 650; contentItem: HudText { text: root.hint; font.pixelSize: 10 } background: Rectangle { color: Theme.background; border.color: Theme.border } }
}
