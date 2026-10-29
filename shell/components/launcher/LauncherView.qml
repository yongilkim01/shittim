import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"

FocusScope {
    id: root
    required property var model
    property bool ready: true
    property bool launching: false
    property string error: ""
    property var iconSource: app => app.iconFile || ""
    signal launchRequested(string appId)
    signal pinRequested(string appId)
    property var isPinned: function(appId) { return false }
    signal closeRequested()
    signal refreshRequested()
    implicitWidth: Theme.launcherWidth
    implicitHeight: Theme.launcherHeight
    readonly property real contentScale: Math.min(1, width / Theme.launcherWidth)
    function focusSearch() { search.forceActiveFocus() }
    function activate() {
        if (root.ready && !root.launching && root.model.selected !== null)
            root.launchRequested(root.model.selected.id)
    }
    onActiveFocusChanged: if (activeFocus) focusSearch()
    HudFrame { anchors.fill: parent; level: "window"; glow: true }
    Item {
        width: Theme.launcherWidth; height: root.height / root.contentScale
        scale: root.contentScale; transformOrigin: Item.TopLeft
        Rectangle { x: 1; y: 32; width: 392; height: 1; color: Theme.accentDim; opacity: 0.7 }
        HudIcon { x: 16; y: 8; width: 16; height: 18; text: "\uf002"; font.pixelSize: 22; color: Theme.accentBright }
        HudInput {
            id: search; objectName: "launcherSearch"
            x: 43; y: 1; width: 315; height: 31
            padding: 0; font.pixelSize: 11; font.letterSpacing: 0.4
            color: Theme.textPrimary; placeholderText: "Search"; background: Item {}
            text: root.model.query
            inputMethodHints: Qt.ImhNoPredictiveText
            onTextEdited: root.model.query = text
            Keys.priority: Keys.BeforeItem
            Keys.onPressed: event => {
                if (search.inputMethodComposing) return
                if (event.key === Qt.Key_Down) root.model.move(1)
                else if (event.key === Qt.Key_Up) root.model.move(-1)
                else if (event.key === Qt.Key_PageDown) root.model.move(5)
                else if (event.key === Qt.Key_PageUp) root.model.move(-5)
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) root.activate()
                else if (event.key === Qt.Key_Escape) root.closeRequested()
                else if (event.key === Qt.Key_F5 || (event.key === Qt.Key_R && event.modifiers & Qt.ControlModifier)) root.refreshRequested()
                else return
                event.accepted = true
            }
        }
        HudText { x: 366; y: 1; width: 18; height: 31; text: "›:"; font.pixelSize: 14; color: Theme.accentDim }
        ListView {
            id: results; objectName: "launcherResults"
            x: 9; y: 41; width: 376; height: Math.max(0, parent.height - y - 4 - (root.error.length > 0 ? 28 : 0))
            clip: true; boundsBehavior: Flickable.StopAtBounds
            model: root.model.results; currentIndex: root.model.selectedIndex
            keyNavigationEnabled: false
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3 }
            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: results.width; height: 28
                readonly property bool selected: index === root.model.selectedIndex
                Rectangle {
                    x: 0; y: 0; width: parent.width; height: 27; radius: 3
                    visible: row.selected
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.22) }
                        GradientStop { position: 1; color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.04) }
                    }
                    border.width: 1; border.color: Theme.accentDim
                    Rectangle { x: 1; y: 1; width: 5; height: parent.height - 2; color: Theme.accent; radius: 1 }
                }
                Image {
                    id: icon; objectName: "launcherAppIcon"
                    x: 17; y: 5; width: 18; height: 18
                    source: root.iconSource(row.modelData); sourceSize.width: 24; sourceSize.height: 24
                    fillMode: Image.PreserveAspectFit; asynchronous: true
                    visible: status === Image.Ready
                }
                HudIcon { x: 17; y: 5; width: 18; height: 18; text: "\uf009"; visible: icon.status !== Image.Ready; color: Theme.textSecondary }
                HudText {
                    x: 49; y: 0; width: Math.max(0, parent.width - x - 88); height: 27
                    text: row.modelData.name; font.pixelSize: 10; font.letterSpacing: 0.2
                    color: row.selected ? Theme.accentBright : Theme.textPrimary
                }
                HudText { x: parent.width - 75; y: 0; width: 62; height: 27; text: "Application"; font.pixelSize: 10; font.letterSpacing: -0.5; color: Theme.accentDim; horizontalAlignment: Text.AlignRight }
                MouseArea {
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onPositionChanged: if (containsMouse) root.model.selectedIndex = row.index
                    onClicked: event => {
                        root.model.selectedIndex = row.index
                        if (event.button === Qt.RightButton) { pinMenu.appId=row.modelData.id; pinMenu.popup() }
                        else { root.focusSearch(); root.activate() }
                    }
                }
            }
        }
        HudText {
            x: 20; y: 48; width: 354; height: 28
            visible: root.model.results.length === 0 && root.error.length === 0
            text: !root.ready ? "앱 목록을 읽는 중…" : "검색 결과 없음"
            font.pixelSize: 11; color: Theme.textSecondary
        }
        HudText {
            x: 14; y: parent.height - 30; width: 366; height: 26
            visible: root.error.length > 0; text: root.error; font.pixelSize: 10; color: Theme.danger
        }
    }
    Controls.Menu {
        id: pinMenu; property string appId: ""
        background: ControlFrame { fillColor:Theme.floatingSurface; strokeColor:Theme.accentDim }
        Controls.MenuItem {
            text: root.isPinned(pinMenu.appId) ? "Dock 고정 해제" : "Dock에 고정"
            contentItem: HudText { text:parent.text }
            onTriggered: root.pinRequested(pinMenu.appId)
        }
    }
}
