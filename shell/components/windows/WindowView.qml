import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"
import "../media"

FocusScope {
    id: root
    property var model: null
    property string error: ""
    property bool cycling: false
    signal requested(string operation, string address)
    signal closeRequested()
    signal commitRequested()
    Keys.onEscapePressed: closeRequested()
    Keys.onUpPressed: if (model) model.step(-1)
    Keys.onDownPressed: if (model) model.step(1)
    Keys.onReturnPressed: if (model && model.selected) requested("activate", model.selected.address)
    Keys.onReleased: event => { if (root.cycling && event.key === Qt.Key_Alt) root.commitRequested() }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Tab && model) { model.step(event.modifiers & Qt.ShiftModifier ? -1 : 1); event.accepted = true }
    }
    ControlFrame { anchors.fill: parent; fillColor: Theme.background; strokeColor: Theme.accentDim; cut: 8 }
    HudText { x: 16; y: 10; width: parent.width - 64; height: 24; text: "WINDOWS"; textStyle: "section"; color: Theme.accent }
    MediaButton { x: parent.width - 42; y: 8; icon: "\uf00d"; tooltipText: "닫기 · Escape"; onClicked: root.closeRequested() }
    ListView {
        id: list; objectName: "windowList"; x: 12; y: 44; width: parent.width - 24; height: Math.max(0, parent.height - 86)
        clip: true; spacing: 1; model: root.model ? root.model.entries : []
        currentIndex: root.model ? root.model.entries.findIndex(window => window.address === root.model.selectedAddress) : -1
        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
        Controls.ScrollBar.vertical: Controls.ScrollBar {}
        delegate: Rectangle {
            id: row; required property var modelData; width: list.width; height: 60
            color: root.model && root.model.selectedAddress === modelData.address ? Theme.surfaceElevated : Theme.background
            border.width: root.model && root.model.selectedAddress === modelData.address ? 1 : 0; border.color: Theme.accentDim
            HudText { objectName: "window-title-" + row.modelData.address; x: 10; y: 6; width: Math.max(0, parent.width - 230); height: 23; text: String(row.modelData.title || row.modelData.className).slice(0, 512); font.pixelSize: 12 }
            HudText { x: 10; y: 31; width: Math.max(0, parent.width - 230); height: 20; font.pixelSize: 10; color: Theme.textSecondary
                text: row.modelData.className + " · " + (row.modelData.hidden ? "숨김" : row.modelData.workspace) }
            MouseArea { x: 0; y: 0; width: parent.width - 218; height: parent.height; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onEntered: if (root.model) root.model.selectedAddress = row.modelData.address
                onClicked: root.requested("activate", row.modelData.address) }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter; spacing: 3
                MediaButton { objectName: "window-hide-" + row.modelData.address; icon: row.modelData.hidden ? "\uf06e" : "\uf068"; tooltipText: row.modelData.hidden ? "복원" : "숨기기"; onClicked: root.requested(row.modelData.hidden ? "activate" : "hide", row.modelData.address) }
                MediaButton { objectName: "window-maximize-" + row.modelData.address; icon: row.modelData.maximized ? "\uf2d2" : "\uf2d0"; tooltipText: row.modelData.maximized ? "복원" : "최대화"; enabled: !row.modelData.hidden && !(row.modelData.fullscreen & 2); onClicked: root.requested("maximize", row.modelData.address) }
                MediaButton { icon: "\uf065"; tooltipText: "전체 화면 전환"; enabled: !row.modelData.hidden; onClicked: root.requested("fullscreen", row.modelData.address) }
                MediaButton { icon: "\uf009"; tooltipText: "Floating / Tiling"; enabled: !row.modelData.hidden; onClicked: root.requested("tile", row.modelData.address) }
                MediaButton { icon: "\uf0b2"; tooltipText: "현재 화면 안으로 정렬"; enabled: !row.modelData.hidden && row.modelData.floating && !row.modelData.fullscreen; onClicked: root.requested("fit", row.modelData.address) }
                MediaButton { icon: "\uf00d"; tooltipText: "창 닫기"; onClicked: root.requested("close", row.modelData.address) }
            }
            Rectangle { height: 1; x: 8; width: parent.width - 16; anchors.bottom: parent.bottom; color: Theme.border }
        }
        HudText { visible: list.count === 0; anchors.centerIn: parent; text: "NO OPEN WINDOWS"; color: Theme.textMuted }
    }
    HudText { x: 16; y: parent.height - 34; height: 24; width: parent.width - 32; font.pixelSize: 10; color: root.error ? Theme.warning : Theme.textSecondary
        text: root.error || "↑ ↓ 선택 · Enter 활성화 · Escape 취소" }
}
