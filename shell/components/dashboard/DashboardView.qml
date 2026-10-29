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
    readonly property var menu: [{title: "시스템", key: "system", icon: ""}, {title: "앱", key: "apps", icon: ""},
        {title: "블루투스", key: "bluetooth", icon: ""}, {title: "디스플레이", key: "display", icon: ""},
        {title: "네트워크", key: "network", icon: ""}, {title: "오디오", key: "audio", icon: ""},
        {title: "전원 관리", key: "power", icon: ""}, {title: "개인 설정", key: "settings", icon: ""}]
    readonly property int selectedIndex: Math.max(0, menu.findIndex(item => item.key === page))
    Keys.onEscapePressed: root.closeRequested()
    HudFrame { anchors.fill: parent; level: "window" }
    Flickable {
        objectName:"dashboardViewport"
        anchors.fill:parent;clip:true;contentWidth:Theme.dashboardWidth;contentHeight:Theme.dashboardHeight;boundsBehavior:Flickable.StopAtBounds
    Item {
        width: Theme.dashboardWidth; height: Theme.dashboardHeight; scale: root.contentScale; transformOrigin: Item.TopLeft
        // Sidebar rail: a dim line with a bright marker that follows the selected entry.
        Rectangle { x: 125; y: 10; width: 1; height: 280; color: Theme.border; opacity: 0.7 }
        Rectangle {
            x: 124; width: 3; height: 21; color: Theme.accent
            y: 18 + root.selectedIndex * 33 + 6
            Behavior on y { NumberAnimation { duration: Theme.panelDuration; easing.type: Theme.easing } }
        }
        Repeater {
            model: root.menu
            HudFrame {
                id: entry
                required property var modelData
                required property int index
                objectName: "dashboardMenu-" + modelData.key
                x: 6; y: 18 + index * 33; width: 112; height: 31
                level: "control"
                cutTopLeft: 0; cutTopRight: 0; cutBottomLeft: 0; cutBottomRight: 6
                active: root.page === modelData.key
                hovered: menuHover.containsMouse || entry.activeFocus
                fillColor: active ? Theme.selectedFill : hovered ? Theme.hoverFill : Theme.transparent
                gradientColor: active ? Theme.transparent : fillColor
                strokeColor: active ? Theme.accent : hovered ? Theme.accentDim : Theme.transparent
                Rectangle {
                    x: 0; y: 0; width: Theme.sectionBarWidth; height: parent.height; color: Theme.accent
                    opacity: parent.active ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.stateDuration; easing.type: Theme.easing } }
                }
                HudIcon { x: 14; y: 7; width: 17; height: 17; text: modelData.icon; font.pixelSize: 16; color: parent.active ? Theme.accent : parent.hovered ? Theme.accentBright : Theme.textSecondary }
                HudText { x: 40; y: 0; width: 70; height: 31; text: modelData.title; font.pixelSize: 11; font.bold: parent.active; color: parent.active ? Theme.textPrimary : Theme.textSecondary }
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
