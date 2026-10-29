import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"

FocusScope {
    id: root
    required property var model
    property string ownership: "owned"
    property int ownerPid: 0
    property string tab: "all"
    property int expandedId: -1
    property real now: Date.now()
    property bool active: true
    readonly property var results: model.history.filter(entry => tab === "all" || entry.category === tab)
    readonly property real contentScale: Math.min(1, width / Theme.notificationWidth)
    signal closeRequested()
    signal dndRequested()
    signal actionRequested(int id, string actionId)
    implicitWidth: Theme.notificationWidth; implicitHeight: Theme.notificationHeight
    Keys.onEscapePressed: root.closeRequested()
    HudFrame { anchors.fill: parent; level: "window"; glow: true }
    Item {
        width: Theme.notificationWidth; height: root.height / root.contentScale
        scale: root.contentScale; transformOrigin: Item.TopLeft
        Rectangle { x: 1; y: 33; width: 358; height: 1; color: Theme.accentDim; opacity: 0.7 }
        Repeater {
            model: [{name: "ALL", key: "all", x: 22, width: 29}, {name: "SYSTEM", key: "system", x: 71, width: 51}, {name: "APP", key: "app", x: 142, width: 29}]
            Item {
                required property var modelData
                x: modelData.x; y: 1; width: modelData.width; height: 33
                HudText { anchors.fill: parent; text: modelData.name; font.pixelSize: 10; font.letterSpacing: 1; color: root.tab === modelData.key ? Theme.accentBright : Theme.accentDim }
                Rectangle { x: 0; y: 32; width: parent.width - 6; height: 1; visible: root.tab === modelData.key; color: Theme.accentBright }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = modelData.key }
            }
        }
        HudIcon {
            objectName: "notificationDnd"; x: 206; y: 8; width: 18; height: 18; text: "\uf186"; font.pixelSize: 14
            color: ["conflict", "error"].indexOf(root.ownership) >= 0 ? Theme.warning : root.model.dnd ? Theme.accent : Theme.textMuted
            MouseArea { id: dndMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: root.ownership === "owned" ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: if (root.ownership === "owned") root.dndRequested() }
            HudToolTip { visible: dndMouse.containsMouse; text: parent.hint }
            readonly property string hint: root.ownership === "conflict" ? "다른 알림 서버가 실행 중입니다. PID " + root.ownerPid : root.ownership !== "owned" ? "Shittim 알림 서버 소유권을 확인하세요." : root.model.dnd ? "방해 금지 사용 중 · 긴급 알림은 표시" : "방해 금지 켜기"
        }
        HudText {
            x: 280; y: 1; width: 57; height: 33; text: "Clear All"; font.pixelSize: Theme.textCaption; horizontalAlignment: Text.AlignRight
            color: root.model.entries.length > 0 ? Theme.accentBright : Theme.textMuted
            MouseArea { anchors.fill: parent; enabled: root.model.entries.length > 0; cursorShape: Qt.PointingHandCursor; onClicked: root.model.clear() }
        }
        ListView {
            id: list; objectName: "notificationList"; x: 1; y: 44; width: 358; height: Math.max(0, parent.height - y - 2)
            model: root.results; clip: true; boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3 }
            delegate: NotificationRow {
                required property var modelData
                objectName: "notification-row-" + modelData.id
                width: list.width; height: implicitHeight; entry: modelData; now: root.now; expanded: entry.id === root.expandedId
                onActivated: { root.expandedId = expanded ? -1 : entry.id; root.model.replace(entry.id, {read: true}) }
                onDismissed: root.model.remove(entry.id)
                onActionRequested: actionId => root.actionRequested(entry.id, actionId)
            }
        }
        HudText {
            x: 24; y: 55; width: 312; height: 96; visible: root.results.length === 0
            text: root.ownership === "conflict" ? "다른 알림 서버가 실행 중입니다.\nPID " + root.ownerPid + " · verify-notifications.sh로 확인하세요."
                : root.ownership === "error" ? "알림 서비스 상태를 확인하지 못했습니다.\npython-dbus-next 설치를 확인하세요."
                : root.ownership === "checking" || root.ownership === "missing" ? "알림 서버 연결 대기 중…"
                : root.model.dnd ? "알림 없음 · 방해 금지 사용 중" : "알림 없음"
            wrapMode: Text.WordWrap; maximumLineCount: 5; font.pixelSize: 10; color: root.ownership === "conflict" ? Theme.warning : Theme.textSecondary
        }
    }
    Timer { interval: 30000; repeat: true; running: root.active && root.visible; onTriggered: root.now = Date.now() }
    onActiveChanged: if (active) now = Date.now()
    onVisibleChanged: if (visible) now = Date.now()
}
