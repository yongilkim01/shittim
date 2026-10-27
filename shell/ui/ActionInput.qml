import QtQuick
import QtQuick.Controls.Basic as Controls

// Shared behavior only. Each control keeps its own HUD drawing.
Item {
    id: root
    anchors.fill: parent
    required property string label
    property bool contextEnabled: false
    property bool focusFrame:false
    readonly property bool hovered: mouse.containsMouse
    readonly property bool pressed: mouse.pressed
    readonly property bool focused: activeFocus || parent.activeFocus
    signal triggered()
    signal contextRequested()
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: label
    Accessible.onPressAction: if(enabled) triggered()
    Keys.onPressed: event => {
        if(!enabled)return
        if([Qt.Key_Return,Qt.Key_Enter,Qt.Key_Space].indexOf(event.key)>=0){triggered();event.accepted=true}
        else if(contextEnabled && (event.key===Qt.Key_Menu || event.key===Qt.Key_F10 && (event.modifiers & Qt.ShiftModifier))){contextRequested();event.accepted=true}
    }
    Rectangle {anchors.fill:parent;visible:root.focusFrame && root.focused;color:Theme.transparent;border.color:Theme.accent;border.width:Theme.lineWidth}
    MouseArea {
        id:mouse;anchors.fill:parent;hoverEnabled:true
        anchors.leftMargin:-Math.max(0,(Theme.minimumTarget-root.width)/2)
        anchors.rightMargin:anchors.leftMargin
        anchors.topMargin:-Math.max(0,(Theme.minimumTarget-root.height)/2)
        anchors.bottomMargin:anchors.topMargin
        acceptedButtons:root.contextEnabled ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        cursorShape:root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked:event=>{if(event.button===Qt.RightButton)root.contextRequested();else root.triggered()}
    }
    Controls.ToolTip {
        visible:root.enabled && (mouse.containsMouse || root.activeFocus) && root.label.length>0
        delay:Theme.tooltipDelay
        contentItem:HudText {text:root.label;font.pixelSize:Theme.textCaption;maximumLineCount:4;wrapMode:Text.Wrap;width:Math.min(280,implicitWidth)}
        background:Rectangle {color:Theme.background;border.color:Theme.border}
    }
}
