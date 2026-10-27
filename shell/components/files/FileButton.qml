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
    Keys.forwardTo:[input]
    implicitWidth: Theme.minimumTarget; implicitHeight: Theme.minimumTarget
    Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 2; color: root.active ? Theme.fileActive : input.hovered ? Theme.surfaceElevated : Theme.transparent; border.width: 1; border.color: input.focused ? Theme.accent : root.active || input.hovered ? Theme.border : Theme.transparent }
    FileGlyph { anchors.centerIn: parent; width: root.windowControl ? Theme.windowButtonSize : Theme.iconSize; height: width; windowControl: root.windowControl; glyph: root.glyph; ink: root.enabled ? root.ink : Theme.textMuted }
    ActionInput {id:input;label:root.hint;onTriggered:root.clicked()}
}
