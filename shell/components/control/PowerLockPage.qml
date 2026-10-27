import QtQuick
import "../../ui"
import "../../core/PowerText.js" as PowerText

// "전원 및 잠금" dashboard page. `policy` is PowerPolicyState (or a test fixture with the same members);
// the page only reads it and calls setValue(), so it never touches files or system commands itself.
FocusScope {
	id: root
	required property var policy
	property url wallpaper: ""
	property string source: policy.hasBattery && policy.currentSource === "battery" ? "battery" : "ac"
	property string openKey: ""
	property int highlighted: -1
	property Item returnFocus: null
	readonly property var current: policy.settings ? policy.settings[source] : null
	readonly property string systemLid: policy.systemLid ? policy.systemLid[source] || "" : ""
	readonly property var rows: [{key: "lock", title: "자동 잠금"}, {key: "screenOff", title: "화면 끄기"},
		{key: "suspend", title: "자동 절전"}, {key: "lid", title: "노트북 덮개를 닫을 때"}].filter(row => row.key !== "lid" || root.policy.hasLid)
	readonly property var options: openKey ? PowerText.options(openKey, systemLid) : []
	readonly property int openIndex: rows.findIndex(row => row.key === openKey)
	implicitWidth: 589; implicitHeight: 272

	function value(key) { return current ? current[key] : undefined }
	function open(key, origin) {
		if (!current || policy.saving) return
		openKey = key
		highlighted = Math.max(0, options.findIndex(option => option.value === value(key)))
		returnFocus = origin || null
		list.forceActiveFocus()
	}
	function close() {
		openKey = ""; highlighted = -1
		if (returnFocus) returnFocus.forceActiveFocus()
		returnFocus = null
	}
	function choose(index) {
		const option = options[index]
		if (option && option.value !== value(openKey)) policy.setValue(source, openKey, option.value)
		close()
	}
	function selectSource(value) { if (value !== "battery" || policy.hasBattery) { source = value; close() } }

	function handleKey(event) {
		if (!openKey) return
		if (event.key === Qt.Key_Down) highlighted = Math.min(options.length - 1, highlighted + 1)
		else if (event.key === Qt.Key_Up) highlighted = Math.max(0, highlighted - 1)
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) choose(highlighted)
		else if (event.key === Qt.Key_Escape) close()
		else return
		event.accepted = true
	}

	HudText { x: 0; y: 0; height: 24; text: "전원 및 잠금"; font.pixelSize: 18; font.bold: true; color: Theme.textPrimary }
	Rectangle { x: 0; y: 29; width: 384; height: 1; color: Theme.border }
	Rectangle { x: 0; y: 28; width: 64; height: 2; color: Theme.accent }

	Repeater {
		model: [{key: "battery", title: "배터리 사용 시", icon: "󰁹"}, {key: "ac", title: "전원 연결 시", icon: "󰚥"}]
		ControlFrame {
			required property var modelData
			required property int index
			objectName: "powerSource-" + modelData.key
			readonly property bool available: modelData.key === "ac" || root.policy.hasBattery
			x: index * 193; y: 38; width: 191; height: 30; cut: 4
			active: root.source === modelData.key
			fillColor: active ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : sourceMouse.containsMouse && available ? Theme.surface : Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.6)
			strokeColor: active ? Theme.accent : Theme.border
			Row {
				anchors.centerIn: parent; spacing: Theme.spaceS
				HudIcon { text: modelData.icon; font.pixelSize: 15; color: !parent.parent.available ? Theme.textMuted : parent.parent.active ? Theme.accentBright : Theme.textSecondary }
				HudText {
					text: modelData.title + (parent.parent.available ? "" : " · 배터리 없음"); font.pixelSize: 11
					color: !parent.parent.available ? Theme.textMuted : parent.parent.active ? Theme.accentBright : Theme.textSecondary
				}
			}
			MouseArea {
				id: sourceMouse; anchors.fill: parent; hoverEnabled: true
				cursorShape: parent.available ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.selectSource(modelData.key)
			}
			activeFocusOnTab: available
			Keys.onReturnPressed: root.selectSource(modelData.key)
			Keys.onSpacePressed: root.selectSource(modelData.key)
		}
	}

	Repeater {
		model: root.rows
		ControlFrame {
			id: row
			required property var modelData
			required property int index
			objectName: "powerRow-" + modelData.key
			x: 0; y: 78 + index * 38; width: 384; height: 32; cut: 4
			active: root.openKey === modelData.key || activeFocus
			fillColor: rowMouse.containsMouse ? Theme.surfaceElevated : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.72)
			strokeColor: active ? Theme.accent : Theme.border
			HudText { x: Theme.spaceM; anchors.verticalCenter: parent.verticalCenter; text: modelData.title; font.pixelSize: 12; color: Theme.textPrimary }
			HudText {
				objectName: "powerValue-" + modelData.key
				anchors.right: chevron.left; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter
				text: root.current ? PowerText.label(modelData.key, root.value(modelData.key), root.systemLid) : "불러오는 중"
				font.pixelSize: 12; color: Theme.textPrimary
			}
			HudIcon {
				id: chevron; anchors.right: parent.right; anchors.rightMargin: Theme.spaceM; anchors.verticalCenter: parent.verticalCenter
				text: root.openKey === modelData.key ? "󰅃" : "󰅀"; font.pixelSize: 14; color: parent.active ? Theme.accentBright : Theme.textSecondary
			}
			MouseArea {
				id: rowMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
				onClicked: root.openKey === modelData.key ? root.close() : root.open(modelData.key, row)
			}
			activeFocusOnTab: true
			Keys.onReturnPressed: root.open(modelData.key, row)
			Keys.onSpacePressed: root.open(modelData.key, row)
		}
	}

	Rectangle { x: 0; y: 234; width: 384; height: 1; color: Theme.border; opacity: 0.7 }
	HudIcon { x: 2; y: 244; text: "󰋽"; font.pixelSize: 13; color: root.policy.applyState === "applied" || root.policy.applyState === "pending" ? Theme.textSecondary : Theme.warning }
	HudText {
		objectName: "powerStatus"
		x: 22; y: 241; width: 362; height: 30; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
		font.pixelSize: 10; verticalAlignment: Text.AlignTop
		text: root.policy.error || (root.policy.saving ? "저장 중…" : PowerText.status(root.policy.applyState, root.policy.currentSource))
		color: root.policy.error ? Theme.danger : root.policy.applyState === "applied" || root.policy.applyState === "pending" ? Theme.textSecondary : Theme.warning
	}

	ControlFrame {
		x: 400; y: 0; width: 189; height: 272; cut: 6
		fillColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.55); strokeColor: Theme.border
		HudText { x: Theme.spaceM; y: 8; text: "잠금 화면 미리보기"; font.pixelSize: 10; color: Theme.textSecondary }
		LockPreview { x: Theme.spaceM; y: 28; width: parent.width - Theme.spaceM * 2; height: parent.height - 40; wallpaper: root.wallpaper }
	}

	// Option list stays inside the page so the dashboard surface never clips it.
	MouseArea { anchors.fill: parent; visible: root.openKey !== ""; z: 9; onClicked: root.close() }
	ControlFrame {
		id: list; objectName: "powerOptions"
		visible: root.openKey !== "" && root.openIndex >= 0; z: 10
		width: 196; height: root.options.length * 24 + 8; cut: 4
		x: 384 - width
		y: Math.max(0, Math.min(root.height - height, 78 + Math.max(0, root.openIndex) * 38 + 34))
		fillColor: Theme.floatingSurface; strokeColor: Theme.accentDim
		Keys.onPressed: event => root.handleKey(event)
		Column {
			x: 4; y: 4; width: parent.width - 8
			Repeater {
				model: root.options
				Rectangle {
					required property var modelData
					required property int index
					objectName: "powerOption-" + modelData.value
					width: parent.width; height: 24
					readonly property bool selected: modelData.value === root.value(root.openKey)
					color: index === root.highlighted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Theme.transparent
					HudText { x: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.pixelSize: 11; color: parent.selected ? Theme.accentBright : Theme.textPrimary }
					HudIcon { anchors.right: parent.right; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; visible: parent.selected; text: "󰄬"; font.pixelSize: 12; color: Theme.accentBright }
					MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.highlighted = index; onClicked: root.choose(index) }
				}
			}
		}
	}
}
