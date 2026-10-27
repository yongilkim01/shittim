import QtQuick
import "../../ui"
import "../control"

FocusScope {
    id: root
    required property var model
    property string page: "system"
    property Component detailComponent: null
    signal navigate(string destination)
    signal closeRequested()
    implicitWidth: Theme.dashboardWidth; implicitHeight: Theme.dashboardHeight
    readonly property real contentScale: 1
    Keys.onEscapePressed: root.closeRequested()
    ControlFrame { anchors.fill: parent; cut: 4; strokeColor: Theme.accentDim; fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98) }
    Flickable {
        objectName:"dashboardViewport"
        anchors.fill:parent;clip:true;contentWidth:Theme.dashboardWidth;contentHeight:Theme.dashboardHeight;boundsBehavior:Flickable.StopAtBounds
    Item {
        width: Theme.dashboardWidth; height: Theme.dashboardHeight; scale: root.contentScale; transformOrigin: Item.TopLeft
        Rectangle { x: 125; y: 1; width: 1; height: 298; color: Theme.border; opacity: 0.7 }
        Repeater {
            model: [{title: "System", key: "system", icon: "\uf2db"}, {title: "Apps", key: "apps", icon: "\uf009"},
                {title: "Bluetooth", key: "bluetooth", icon: "\uf294"}, {title: "Display", key: "display", icon: "\uf108"},
                {title: "Network", key: "network", icon: "\uf1eb"}, {title: "Audio", key: "audio", icon: "\uf028"},
                {title: "Power", key: "power", icon: "\uf011"}, {title: "Settings", key: "settings", icon: "\uf013"}]
            ControlFrame {
                required property var modelData
                required property int index
                objectName: "dashboardMenu-" + modelData.key
                x: 1; y: 18 + index * 33; width: 110; height: 33; cut: 4
                active: root.page === modelData.key
                fillColor: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.2) : menuHover.containsMouse ? Theme.surface : Theme.transparent
                gradientColor: active ? Theme.background : fillColor
                strokeColor: active ? Theme.accent : Theme.transparent
                Rectangle { x: 0; y: 1; width: 5; height: parent.height - 2; color: Theme.accent; visible: parent.active }
                Rectangle { x: 5; y: 1; width: 23; height: parent.height - 2; color: Theme.accent; opacity: 0.15; visible: parent.active }
                HudIcon { x: 20; y: 8; width: 17; height: 17; text: modelData.icon; font.pixelSize: 22; color: parent.active ? Theme.accent : Theme.textSecondary }
                HudText { x: 46; y: 0; width: 64; height: 33; text: modelData.title; font.pixelSize: 10; color: parent.active ? Theme.accent : Theme.textSecondary }
                MouseArea { id: menuHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.navigate(modelData.key) }
                activeFocusOnTab: true
                Keys.onReturnPressed: root.navigate(modelData.key)
                Keys.onSpacePressed: root.navigate(modelData.key)
            }
        }
        SystemOverview { anchors.fill: parent; model: root.model; visible: root.page === "system" }
        Loader { objectName: "dashboardDetail"; x: 140; y: 15; width: 589; height: 272; active: root.page !== "system"; sourceComponent: root.detailComponent }
    }
    }
}
