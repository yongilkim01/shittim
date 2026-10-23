import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"
import "MediaData.js" as Data

FocusScope {
    id: root
    property var model: null
    property var apps: []
    property var iconSource: function(app) { return "" }
    property var isRunning: function(app) { return false }
    property bool ready: false
    property bool launching: false
    property bool active: true
    property string error: ""
    signal appRequested(var app)
    signal refreshRequested()
    signal closeRequested()
    readonly property real contentScale: Math.min(width / Theme.mediaWidth, height / Theme.mediaHeight)
    readonly property string artworkState: cover.status === Image.Ready ? "ready" : cover.status === Image.Loading ? "loading" : cover.status === Image.Error ? "error" : "unloaded"
    Keys.onEscapePressed: closeRequested()
    Keys.onPressed: event => { if (event.key === Qt.Key_F5) { refreshRequested(); event.accepted = true } }
    Item {
        width: Theme.mediaWidth; height: Theme.mediaHeight
        scale: root.contentScale; transformOrigin: Item.TopLeft
        MediaFrame {
            objectName: "mediaPlayerFrame"; width: 349; height: 163; cut: 8
            Image {
                id: cover; objectName: "mediaArtwork"; x: 24; y: 27; width: 88; height: 88
                source: root.active && root.model ? root.model.art : ""; asynchronous: true
                sourceSize.width: 176; sourceSize.height: 176; fillMode: Image.PreserveAspectCrop
            }
            HudIcon { x: 24; y: 27; width: 88; height: 88; font.pixelSize: 36; text: "\uf001"; color: Theme.textMuted; visible: cover.status !== Image.Ready }
            HudText {
                objectName: "mediaTitle"; x: 129; y: 29; width: 194; height: 22; font.pixelSize: 13
                text: root.model ? root.model.title : "NO ACTIVE MEDIA"
            }
            HudText { objectName: "mediaArtist"; x: 129; y: 51; width: 194; height: 22; font.pixelSize: 12; text: root.model ? root.model.artist : ""; color: Theme.accentBright }
            MouseArea {
                id: playerChoice; x: 24; y: 22; width: 300; height: 63; hoverEnabled: true
                enabled: root.model !== null && root.model.players.length > 1
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.model.cyclePlayer()
                Controls.ToolTip {
                    visible: playerChoice.containsMouse; delay: 450
                    contentItem: HudText { text: root.model && root.model.player ? Data.text(root.model.player.identity) + " · 클릭하여 플레이어 전환" : ""; font.pixelSize: 10 }
                    background: Rectangle { color: Theme.background; border.color: Theme.border }
                }
            }
            HudSlider {
                id: seek; objectName: "mediaSeek"; x: 129; y: 85; width: 194; height: 16
                padding: 0; trackHeight: 3; handleSize: hovered || pressed ? 6 : 0; stepSize: 0
                enabled: root.model !== null && root.model.seekable
                // Live broadcasts can have a position without a known duration.
                Binding { target: seek; property: "value"; value: root.model && root.model.duration > 0 && root.model.position >= 0 ? Math.min(1, root.model.position / root.model.duration) : 0; when: !seek.pressed }
                onPressedChanged: {
                    if (!root.model) return
                    if (pressed) root.model.beginSeek()
                    else root.model.finishSeek(value)
                }
            }
            HudText {
                objectName: "mediaElapsed"; x: 129; y: 100; width: 90; height: 17; font.pixelSize: 9; color: Theme.textSecondary
                text: Data.time(seek.pressed && root.model ? seek.value * root.model.duration : root.model ? root.model.position : -1)
            }
            HudText { x: 257; y: 100; width: 66; height: 17; font.pixelSize: 9; horizontalAlignment: Text.AlignRight; color: Theme.textSecondary; text: Data.time(root.model ? root.model.duration : -1) }
            MediaButton { objectName: "mediaPrevious"; x: 176; y: 112; icon: "\uf048"; tooltipText: "이전 곡"; enabled: root.model !== null && root.model.canPrevious; onClicked: root.model.previous() }
            MediaButton { objectName: "mediaToggle"; x: 216; y: 112; icon: root.model && root.model.playing ? "\uf04c" : "\uf04b"; tooltipText: root.model && root.model.playing ? "일시정지" : "재생"; enabled: root.model !== null && root.model.canToggle; onClicked: root.model.toggle() }
            MediaButton { objectName: "mediaNext"; x: 256; y: 112; icon: "\uf051"; tooltipText: "다음 곡"; enabled: root.model !== null && root.model.canNext; onClicked: root.model.next() }
        }
        HudText { x: 10; y: 171; width: 329; height: 22; text: "웹 앱"; font.pixelSize: 10; color: Theme.accentBright; font.letterSpacing: 1.5 }
        MediaFrame {
            id: dock; objectName: "mediaDockFrame"; y: 199; width: 349; height: 72; cut: 4
            Flickable {
                id: viewport; x: 24; y: 15; width: 301; height: 42
                contentWidth: buttons.width; contentHeight: 42; clip: true
                flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: buttons; height: 42; spacing: 10
                    Repeater {
                        model: root.apps
                        MediaButton {
                            required property var modelData
                            objectName: "dock-" + modelData.id; width: 42; height: 42; framed: true
                            imageSource: root.iconSource(modelData); icon: "\uf2d0"
                            tooltipText: Data.text(modelData.name); enabled: root.ready && !root.launching
                            running: root.isRunning(modelData)
                            onClicked: root.appRequested(modelData)
                        }
                    }
                }
            }
            HudText {
                visible: root.apps.length === 0; anchors.centerIn: parent; width: 300; horizontalAlignment: Text.AlignHCenter
                text: root.ready ? "NO PINNED APPS" : "LOADING APPS"; color: Theme.textMuted; font.pixelSize: 10
            }
        }
        // Errors appear only when needed, inside the original section-label strip.
        HudText { objectName: "mediaError"; x: 65; y: 171; width: 274; height: 22; visible: root.error.length > 0; text: root.error; font.pixelSize: 9; color: Theme.warning }
    }
}
