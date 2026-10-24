import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"

FocusScope {
    id: root
    property var apps: []
    property var favorites: []
    property var matches: function(app) { return [] }
    property var iconSource: function(app) { return "" }
    property string mode: ""
    property var app: null
    property var windows: []
    property var target: null
    property string error:""
    property Component previewContent: null
    readonly property alias stripItem: strip
    readonly property alias popupItem: popup
    readonly property alias errorItem:errorLabel
    signal appClicked(var app)
    signal appHovered(var app)
    signal appMenu(var app)
    signal actionRequested(string operation)
    signal windowChosen(string address)
    signal targetChosen(string address)
    signal reorderRequested(string appId, int index)
    signal launcherRequested()
    signal closeRequested()
    signal hoverLeft()
    signal hoverEntered()
    readonly property real stripWidth: Math.min(width, apps.length * Theme.dockCellSize + 70)
    readonly property real popupHeight: Math.min(mode === "menu" ? 330 : mode ? 208 : 0,Math.max(0,height-Theme.dockHeight-12))
    Keys.onEscapePressed: closeRequested()
    ControlFrame {
        id: strip; objectName: "desktopDockStrip"
        width: root.stripWidth; height: Theme.dockHeight; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        cut: 10; strokeColor: Theme.accentDim; fillColor: Theme.floatingSurface
        Flickable {
            id:appScroll
            x: 12; y: 8; width: parent.width - 62; height: parent.height - 16
            contentWidth: icons.width; clip: true; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: icons
                Repeater {
                    model: root.apps
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: Theme.dockCellSize; height: 54
                        readonly property var clients: root.matches(modelData)
                        readonly property bool allHidden: clients.length > 0 && clients.every(window => window.hidden)
                        Rectangle {
                            x: 5; y: 0; width: 48; height: 48; radius: 2
                            color: hover.containsMouse ? Theme.selectionFill : Theme.transparent
                            border.width: 1; border.color: cell.clients.some(window => window.activated) ? Theme.accent : hover.containsMouse ? Theme.border : Theme.transparent
                            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                        }
                        Image { objectName:"dock-image-"+cell.modelData.id; x: 10; y: 5; width: Theme.dockIconSize; height: Theme.dockIconSize; source: root.iconSource(cell.modelData); sourceSize.width: 76; sourceSize.height: 76; opacity: cell.allHidden ? 0.4 : 1; asynchronous: true }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 49; spacing: 3
                            Repeater { model: Math.min(4, cell.clients.length); Rectangle { width: 3; height: 3; radius: 1.5; color: Theme.accent; opacity: cell.allHidden ? 0.5 : 1 } }
                        }
                        MouseArea {
                            id: hover; objectName: "dock-app-" + cell.modelData.id; anchors.fill: parent
                            hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
                            preventStealing:true
                            property real pressX: 0
                            onEntered: { root.hoverEntered(); root.appHovered(cell.modelData) }
                            onExited: root.hoverLeft()
                            onPressed: mouse => { pressX = mouse.x }
                            onReleased: mouse => {
                                if (mouse.button === Qt.LeftButton && Math.abs(mouse.x - pressX) > 22 && root.favorites.indexOf(cell.modelData.id) >= 0)
                                    root.reorderRequested(cell.modelData.id, root.favorites.indexOf(cell.modelData.id) + Math.round((mouse.x - pressX) / Theme.dockCellSize))
                            }
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) root.appMenu(cell.modelData)
                                else if (Math.abs(mouse.x - pressX) <= 22) root.appClicked(cell.modelData)
                            }
                        }
                    }
                }
            }
        }
        HudButton { x: parent.width - 45; y: 12; width: 32; height: 40; text: "\uf009"; onClicked: root.launcherRequested() }
    }
    ControlFrame {
        id: popup; objectName: "dockPopup"
        visible: root.mode.length > 0 && root.app !== null
        anchors.bottom: strip.top; anchors.bottomMargin: 10
        x:Math.max(0,Math.min(root.width-width,strip.x+12+Math.max(0,root.apps.findIndex(candidate=>root.app && candidate.id===root.app.id))*Theme.dockCellSize+Theme.dockCellSize/2-appScroll.contentX-width/2))
        width: Math.min(root.width, root.mode === "menu" ? 282 : Math.max(224, Math.min(3, root.windows.length) * 224))
        height: root.popupHeight; fillColor: Theme.floatingSurface; strokeColor: Theme.accentDim; cut: 8
        HoverHandler { onHoveredChanged: { if (hovered) root.hoverEntered(); else root.hoverLeft() } }
        Flickable {
            visible:root.mode === "menu"; anchors.fill:parent; anchors.margins:8; clip:true
            contentHeight:menuColumn.height; boundsBehavior:Flickable.StopAtBounds
        Column {
            id:menuColumn; width:popup.width-20; spacing:4
            HudText { width: parent.width; height: 24; text: root.app ? root.app.name : ""; color: Theme.accentBright }
            Controls.ComboBox {
                visible: root.windows.length > 1; width: parent.width; height: visible ? 30 : 0
                model: root.windows.map(window => window.title); onActivated: index => root.targetChosen(root.windows[index].address)
                contentItem: HudText { text: parent.displayText; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: Theme.surface; border.color: Theme.border }
                delegate: Controls.ItemDelegate { required property string modelData; width: parent.width; text: modelData; contentItem: HudText { text: parent.text } }
            }
            Repeater {
                model: [{label:"복원 / 활성화",op:"activate",available:root.target !== null},
                    {label:"최소화",op:"hide",available:root.target !== null && !root.target.hidden},
                    {label:"새 창 열기",op:"new",available:true}, {label:"닫기",op:"close",available:root.target !== null},
                    {label:root.app && root.favorites.indexOf(root.app.id) >= 0 ? "Dock 고정 해제" : "Dock에 고정",op:root.app && root.favorites.indexOf(root.app.id) >= 0 ? "unpin" : "pin",available:true}]
                HudButton { required property var modelData; objectName:"dock-action-"+modelData.op; width: popup.width - 20; height: 30; text: modelData.label; enabled: modelData.available; onClicked: root.actionRequested(modelData.op) }
            }
        }
        }
        Flickable {
            visible: root.mode !== "menu"; anchors.fill: parent; anchors.margins: 8
            contentWidth: cards.width; clip: true; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: cards; spacing: 8
                Repeater {
                    model: root.windows
                    delegate: Rectangle {
                        id: card; required property var modelData
                        width: 208; height: 190; color: Theme.surface; border.color: modelData.activated ? Theme.accent : Theme.border
                        HudText { x: 8; y: 5; width: 192; height: 25; text: card.modelData.title }
                        Loader { x: 6; y: 34; width: 196; height: 130; sourceComponent: root.previewContent; property var entry: card.modelData }
                        HudText { x: 8; y: 164; width: 192; height: 20; text: card.modelData.hidden ? "MINIMIZED" : root.app ? root.app.name : ""; color: Theme.textSecondary; font.pixelSize: 10 }
                        MouseArea { objectName: "dock-preview-" + card.modelData.address; anchors.fill: parent; onClicked: root.windowChosen(card.modelData.address) }
                    }
                }
                HudText { visible: root.windows.length === 0; width: 200; height: 80; text: root.app ? root.app.name : ""; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
    HudText {
        id:errorLabel; visible:root.error.length>0 && !root.mode
        anchors.bottom:strip.top; anchors.horizontalCenter:parent.horizontalCenter
        width:Math.min(600,parent.width); height:42; text:root.error; color:Theme.danger; wrapMode:Text.Wrap; horizontalAlignment:Text.AlignHCenter
    }
}
