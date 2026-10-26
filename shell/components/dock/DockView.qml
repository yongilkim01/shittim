import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"
import "../media"

FocusScope {
    id: root
    property var apps: []
    property var favorites: []
    property var matches: function(app) { return [] }
    property var iconSource: function(app) { return "" }
    property var assetSource: function(relative) { return "" }
    property string mode: ""
    property var app: null
    property var windows: []
    property var target: null
    property string error:""
    property bool trashAvailable: true
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
    signal settingsRequested()
    signal trashRequested()
    signal closeRequested()
    signal hoverLeft()
    signal hoverEntered()
    readonly property real stripWidth: Math.min(width, apps.length * Theme.dockCellSize + Theme.dockEndSpace)
    readonly property real popupHeight: Math.min(mode === "menu" ? 330 : mode ? 208 : 0,Math.max(0,height-Theme.dockHeight-12))
    Keys.onEscapePressed: closeRequested()
    Item {
        id: strip; objectName: "desktopDockStrip"
        width: root.stripWidth; height: Theme.dockHeight; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        DockFrame { anchors.fill: parent }
        Flickable {
            id:appScroll
            x: 32; y: 10; width: parent.width - Theme.dockEndSpace; height: parent.height - 16
            contentWidth: icons.width; clip: true; boundsBehavior: Flickable.StopAtBounds
            Row {
                id: icons
                Repeater {
                    model: root.apps
                    delegate: Item {
                        id: cell
                        required property var modelData
                        required property int index
                        width: Theme.dockCellSize; height: 48
                        readonly property var clients: root.matches(modelData)
                        readonly property bool allHidden: clients.length > 0 && clients.every(window => window.hidden)
                        Rectangle {
                            objectName: "dock-highlight-" + cell.modelData.id
                            x: 6; y: 0; width: 40; height: 40; radius: 3
                            color: hover.containsMouse || cell.clients.some(window => window.activated) ? Theme.selectionFill : Theme.transparent
                            border.width: 1; border.color: cell.clients.some(window => window.activated) ? Theme.accentDim : hover.containsMouse ? Theme.border : Qt.alpha(Theme.border, 0.35)
                            Behavior on color { ColorAnimation { duration: Theme.hoverDuration } }
                            Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 5; color: "transparent"; border.width: 2; border.color: Qt.alpha(Theme.accent,0.08); visible: cell.clients.some(window => window.activated) }
                        }
                        Image { objectName:"dock-image-"+cell.modelData.id; x: 10; y: 4; width: Theme.dockIconSize; height: Theme.dockIconSize; source: root.iconSource(cell.modelData); sourceSize.width: Theme.dockIconSize * 2; sourceSize.height: Theme.dockIconSize * 2; fillMode: Image.PreserveAspectFit; opacity: cell.allHidden ? 0.4 : 1; asynchronous: true }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 44; spacing: 3
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
        Rectangle { x: parent.width - 66; y: 12; width: 1; height: parent.height - 24; color: Theme.border }
        MediaButton {
            objectName: "dock-settings"; x: parent.width - 115; y: 12; width: 40; height: 40
            framed: false; imageSource: root.assetSource("icons/Shittim-HUD/scalable/apps/preferences-system.svg"); icon: "\uf013"; tooltipText: "설정 · 우클릭 앱 런처"
            onClicked: root.settingsRequested(); onContextRequested: root.launcherRequested()
        }
        MediaButton {
            objectName: "dock-trash"; x: parent.width - 54; y: 12; width: 40; height: 40
            framed: false; imageSource: root.assetSource("icons/Shittim-HUD/scalable/places/user-trash.svg"); icon: "\uf1f8"; tooltipText: "휴지통 열기"; enabled: root.trashAvailable
            onClicked: root.trashRequested()
        }
    }
    ControlFrame {
        id: popup; objectName: "dockPopup"
        visible: root.mode.length > 0 && root.app !== null
        anchors.bottom: strip.top; anchors.bottomMargin: 10
        x:Math.max(0,Math.min(root.width-width,strip.x+32+Math.max(0,root.apps.findIndex(candidate=>root.app && candidate.id===root.app.id))*Theme.dockCellSize+Theme.dockCellSize/2-appScroll.contentX-width/2))
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
                    {label:root.target && root.target.maximized ? "최대화 해제" : "최대화",op:"maximize",available:root.target !== null && !root.target.hidden && !(root.target.fullscreen & 2)},
                    {label:root.target && (root.target.fullscreen & 2) ? "전체 화면 해제" : "전체 화면",op:"fullscreen",available:root.target !== null && !root.target.hidden},
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
        width:Math.min(600,parent.width); height:visible ? 42 : 0; text:root.error; color:Theme.danger; wrapMode:Text.Wrap; horizontalAlignment:Text.AlignHCenter
    }
}
