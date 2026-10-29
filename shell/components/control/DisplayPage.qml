import QtQuick
import "../../ui"
import "../../core"
import "../../core/DisplayLayout.js" as Layout

// "디스플레이" dashboard page. `display` is DisplayState (or a fixture with the same members): the page edits its draft
// and calls apply/keep/revert, and never runs a command itself. `brightness` keeps the old backlight controls here.
FocusScope {
	id: root
	required property var display
	property var brightness: null
	property string openKey: ""
	property int highlighted: -1
	property Item openRow: null
	property real listY: 0
	readonly property var monitor: display.selectedMonitor
	readonly property var item: display.selectedItem
	readonly property var was: display.selectedCurrent
	readonly property bool locked: display.applying || display.waiting
	readonly property var options: optionsFor(openKey, item, monitor, was)
	readonly property bool consuming: visible && Window.window !== null && Window.window.visible
	implicitWidth: 589; implicitHeight: 272
	ServiceLease { service: root.display; active: root.consuming }
	ServiceLease { service: root.brightness || root.display; active: root.consuming && root.brightness !== null }

	function optionsFor(key, item, monitor, was) {
		if (!key || !item || !monitor) return []
		if (key === "monitor")
			return display.editable.map(entry => ({value: entry.name, label: display.number(entry.name) + " — " + Layout.title(entry)}))
		if (key === "resolution")
			return Layout.resolutions(monitor.modes).map(mode => ({value: mode.width + "x" + mode.height, label: Layout.resolutionLabel(mode.width, mode.height)}))
		if (key === "refresh")
			return Layout.refreshes(monitor.modes, item.width, item.height).map(value => ({value: value, label: Layout.refreshLabel(value)}))
		if (key === "scale")
			return Layout.scaleOptions(item.width, item.height, was && was.width === item.width && was.height === item.height ? was.scale : 0)
		return Layout.transformOptions(was ? was.transform : item.transform)
	}
	function valueOf(key, entry) {
		if (!entry) return ""
		return key === "monitor" ? entry.name : key === "resolution" ? entry.width + "x" + entry.height
			: key === "refresh" ? entry.refresh : key === "scale" ? entry.scale : entry.transform
	}
	function labelOf(key, entry) {
		if (!entry) return ""
		return key === "resolution" ? Layout.resolutionLabel(entry.width, entry.height) : key === "refresh" ? Layout.refreshLabel(entry.refresh)
			: key === "scale" ? Layout.scaleLabel(entry.scale) : key === "transform" ? Layout.transformLabel(entry.transform) : ""
	}
	function differs(key) {
		if (!item || !was || key === "monitor") return false
		const a = valueOf(key, item), b = valueOf(key, was)
		return typeof a === "number" ? Math.abs(a - b) > 0.0001 : a !== b
	}
	function open(key, row) {
		if (locked || !item) return
		openKey = key; openRow = row
		highlighted = Math.max(0, options.findIndex(option => typeof option.value === "number"
			? Math.abs(option.value - valueOf(key, item)) < 0.0001 : option.value === valueOf(key, item)))
		const below = row.mapToItem(root, 0, row.height).y + 2, height = list.height
		listY = below + height <= root.height ? below : Math.max(0, row.mapToItem(root, 0, 0).y - height - 2)
		list.forceActiveFocus()
		optionView.positionViewAtIndex(highlighted, ListView.Contain)
	}
	function close() {
		const row = openRow
		openKey = ""; highlighted = -1; openRow = null
		if (row) row.forceActiveFocus()
	}
	function choose(index) {
		const option = options[index], key = openKey
		close()
		if (!option) return
		if (key === "monitor") display.select(option.value)
		else if (key === "resolution") { const size = option.value.split("x"); display.setResolution(Number(size[0]), Number(size[1])) }
		else if (key === "refresh") display.setRefresh(option.value)
		else if (key === "scale") display.setScale(option.value)
		else display.setTransform(option.value)
	}
	function handleKey(event) {
		if (event.key === Qt.Key_Down) highlighted = Math.min(options.length - 1, highlighted + 1)
		else if (event.key === Qt.Key_Up) highlighted = Math.max(0, highlighted - 1)
		else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) choose(highlighted)
		else if (event.key === Qt.Key_Escape) close()
		else return
		optionView.positionViewAtIndex(highlighted, ListView.Contain)
		event.accepted = true
	}
	onLockedChanged: if (locked && openKey) close()

	component SettingRow: Item {
		id: row
		required property string key
		required property string title
		readonly property bool changed: root.differs(key)
		readonly property bool available: !root.locked && root.item !== null && (key !== "monitor" || root.display.editable.length > 1)
		objectName: "displayRow-" + key
		width: parent ? parent.width : 0; height: 28
		activeFocusOnTab: available
		HudText { x: 0; width: 150; anchors.verticalCenter: parent.verticalCenter; text: row.title; font.pixelSize: 12; color: Theme.textPrimary }
		ControlFrame {
			x: 160; width: parent.width - 160; height: parent.height; cut: 4
			active: root.openKey === row.key || row.activeFocus
			fillColor: rowMouse.containsMouse && row.available ? Theme.surfaceElevated : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.72)
			strokeColor: active ? Theme.accent : Theme.border
			HudText {
				objectName: "displayValue-" + row.key
				x: Theme.spaceM; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 150
				text: !root.item ? "불러오는 중" : row.key === "monitor" ? root.display.number(root.item.name) + " — " + Layout.title(root.monitor) : root.labelOf(row.key, root.item)
				font.pixelSize: 12; color: !row.available ? Theme.textSecondary : row.changed ? Theme.accentBright : Theme.textPrimary
			}
			HudText {
				anchors.right: chevron.left; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter
				visible: row.changed; text: "현재 " + root.labelOf(row.key, root.was); font.pixelSize: 10; color: Theme.textMuted
			}
			HudIcon {
				id: chevron; anchors.right: parent.right; anchors.rightMargin: Theme.spaceM; anchors.verticalCenter: parent.verticalCenter
				text: root.openKey === row.key ? "󰅃" : "󰅀"; font.pixelSize: 14
				color: !row.available ? Theme.textMuted : parent.active ? Theme.accentBright : Theme.textSecondary
			}
			MouseArea {
				id: rowMouse; anchors.fill: parent; hoverEnabled: true; enabled: row.available
				cursorShape: Qt.PointingHandCursor
				onClicked: root.openKey === row.key ? root.close() : root.open(row.key, row)
			}
		}
		Keys.onReturnPressed: root.open(key, row)
		Keys.onSpacePressed: root.open(key, row)
	}

	HudText { x: 0; y: 0; height: 24; text: "디스플레이"; font.pixelSize: 18; font.bold: true; color: Theme.textPrimary }
	Rectangle { x: 0; y: 29; width: 384; height: 1; color: Theme.border }
	Rectangle { x: 0; y: 28; width: 64; height: 2; color: Theme.accent }

	Flickable {
		id: viewport; objectName: "displayViewport"
		x: 0; y: 36; width: parent.width; height: 196
		clip: true; contentWidth: width; contentHeight: column.implicitHeight
		boundsBehavior: Flickable.StopAtBounds; flickableDirection: Flickable.VerticalFlick
		onContentYChanged: if (root.openKey) root.close()
		Column {
			id: column
			width: viewport.width - Theme.spaceS
			spacing: 4
			ControlFrame {
				objectName: "displayArrangementFrame"
				width: parent.width; height: 104; cut: 6
				fillColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.7); strokeColor: Theme.border
				DisplayArrangement {
					id: arrangement; objectName: "displayArrangement"
					x: Theme.spaceS; y: 2; width: parent.width - Theme.spaceS * 2; height: 82
					items: root.display.draft; current: root.display.current; selected: root.display.selected; locked: root.locked
					numberOf: name => root.display.number(name)
					onSelectRequested: name => root.display.select(name)
					onMoveRequested: (name, x, y) => root.display.move(name, x, y)
					onPlaceRequested: (name, direction) => root.display.place(name, direction)
				}
				HudText {
					anchors.horizontalCenter: parent.horizontalCenter; y: 84; height: 16; font.pixelSize: 10; color: Theme.textSecondary
					text: !root.display.ready ? (root.display.loading ? "모니터 정보를 읽는 중…" : "")
						: root.display.editable.length > 1 ? (arrangement.keyboardActive ?"화살표 키로 선택한 화면을 옮길 수 있습니다" : "화면을 드래그하여 위치를 변경하세요")
						: "연결된 모니터가 하나입니다"
				}
			}
			SettingRow { key: "monitor"; title: "모니터" }
			SettingRow { key: "resolution"; title: "해상도" }
			SettingRow { key: "refresh"; title: "주사율" }
			SettingRow { key: "scale"; title: "배율" }
			SettingRow { key: "transform"; title: "방향" }
			Item {
				id: primaryRow; objectName: "displayPrimary"
				readonly property bool available: !root.locked && root.display.editable.length > 1 && root.item !== null
				readonly property bool checked: root.item !== null && (root.display.primary === root.item.name || root.display.editable.length === 1)
				width: parent.width; height: 26
				activeFocusOnTab: available
				Rectangle {
					id: checkBox; x: 0; anchors.verticalCenter: parent.verticalCenter; width: 18; height: 18
					color: primaryRow.checked ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Theme.transparent
					border.width: Theme.lineWidth
					border.color: !primaryRow.available ? Theme.border : primaryRow.activeFocus || primaryMouse.containsMouse ? Theme.accentBright : Theme.accent
					HudIcon { anchors.centerIn: parent; visible: primaryRow.checked; text: "󰄬"; font.pixelSize: 13; color: primaryRow.available ? Theme.accentBright : Theme.textMuted }
				}
				HudText {
					x: 28; anchors.verticalCenter: parent.verticalCenter; text: "주 디스플레이로 사용"; font.pixelSize: 12
					color: primaryRow.available ? Theme.textPrimary : Theme.textSecondary
				}
				MouseArea { id: primaryMouse; x: 0; width: 180; height: parent.height; hoverEnabled: true; enabled: primaryRow.available; cursorShape: Qt.PointingHandCursor; onClicked: root.display.setPrimary(!primaryRow.checked) }
				Keys.onSpacePressed: root.display.setPrimary(!checked)
				Keys.onReturnPressed: root.display.setPrimary(!checked)
			}
			HudText {
				width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 3; font.pixelSize: 10; color: Theme.textMuted
				text: "주 디스플레이: 로그인할 때 마우스 커서와 작업 공간 1이 이 화면에서 시작합니다(다음 로그인부터). 상단 바와 Dock 은 모든 화면에 표시됩니다."
			}
			HudText {
				objectName: "displayDetail"
				width: parent.width; wrapMode: Text.WordWrap; maximumLineCount: 4; font.pixelSize: 10; color: Theme.textSecondary
				text: !root.monitor || !root.was ? "" : "포트 " + root.monitor.name + (root.monitor.description ? " · " + root.monitor.description : "")
					+ "\n현재 " + Layout.resolutionLabel(root.was.width, root.was.height) + " · " + Layout.refreshLabel(root.was.refresh) + " · "
					+ Layout.scaleLabel(root.was.scale) + " · " + Layout.transformLabel(root.was.transform) + " · 위치 " + root.was.x + ", " + root.was.y
					+ (root.display.inactive.length ? "\n꺼져 있거나 복제 중인 모니터(여기서 바꾸지 않음): " + root.display.inactive.map(entry => entry.name).join(", ") : "")
			}
			Item { width: 1; height: Theme.spaceS }
			HudText { visible: root.brightness !== null; text: "밝기"; color: Theme.accent; textStyle: "section" }
			Loader {
				active: root.brightness !== null; width: parent.width
				sourceComponent: BrightnessPage { brightness: root.brightness }
			}
		}
	}

	// The page is taller than the dashboard detail area; this bar says there is more below.
	Rectangle {
		objectName: "displayScroll"
		visible: viewport.contentHeight > viewport.height
		x: parent.width - 2; y: viewport.y + viewport.visibleArea.yPosition * viewport.height
		width: 2; height: Math.max(16, viewport.visibleArea.heightRatio * viewport.height); color: Theme.accentDim
	}
	Rectangle { x: 0; y: 236; width: parent.width; height: 1; color: Theme.border; opacity: 0.7 }
	HudText {
		objectName: "displayMessage"
		x: 0; y: 240; width: 380; height: 30; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
		font.pixelSize: 10; verticalAlignment: Text.AlignVCenter
		readonly property bool warn: root.display.error !== "" || root.display.problem !== "" || !root.display.guardAvailable
		text: root.display.error || root.display.problem || (root.display.applying ? "적용하는 중… 화면이 잠시 깜빡일 수 있습니다." : "")
			|| root.display.outcome || root.display.notice
			|| (!root.display.guardAvailable ? "자동 복구(systemd 사용자 세션)를 쓸 수 없어 설정을 적용할 수 없습니다." : "")
			|| (root.display.dirty ? "적용 전 변경 사항이 있습니다. 적용하면 15초 안에 유지 여부를 묻습니다." : "")
		color: root.display.error ? Theme.danger : warn ? Theme.warning : root.display.dirty || root.display.applying ? Theme.accentBright : Theme.textSecondary
	}
	HudButton {
		objectName: "displayCancel"; x: 389; y: 242; width: 92; text: "취소"
		enabled: root.display.dirty && !root.locked; onClicked: root.display.cancel()
	}
	HudButton {
		objectName: "displayApply"; x: 489; y: 242; width: 100; text: "적용"; active: enabled
		enabled: root.display.canApply && root.display.guardAvailable; onClicked: root.display.apply()
	}

	// Option list stays inside the page so the dashboard surface never clips it.
	MouseArea { anchors.fill: parent; visible: root.openKey !== ""; z: 9; onClicked: root.close() }
	ControlFrame {
		id: list; objectName: "displayOptions"
		visible: root.openKey !== ""; z: 10
		x: 160; y: root.listY; width: root.width - 160 - Theme.spaceS
		height: Math.min(root.options.length, 7) * 24 + 8; cut: 4
		fillColor: Theme.floatingSurface; strokeColor: Theme.accentDim
		Keys.onPressed: event => root.handleKey(event)
		ListView {
			id: optionView
			x: 4; y: 4; width: parent.width - 8; height: parent.height - 8
			clip: true; model: root.options; boundsBehavior: Flickable.StopAtBounds
			delegate: Rectangle {
				required property var modelData
				required property int index
				objectName: "displayOption-" + index
				width: optionView.width; height: 24
				readonly property bool selected: typeof modelData.value === "number" ? Math.abs(modelData.value - root.valueOf(root.openKey, root.item)) < 0.0001
					: modelData.value === root.valueOf(root.openKey, root.item)
				color: index === root.highlighted ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.16) : Theme.transparent
				HudText { x: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.pixelSize: 11; color: parent.selected ? Theme.accentBright : Theme.textPrimary }
				HudIcon { anchors.right: parent.right; anchors.rightMargin: Theme.spaceS; anchors.verticalCenter: parent.verticalCenter; visible: parent.selected; text: "󰄬"; font.pixelSize: 12; color: Theme.accentBright }
				MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onEntered: root.highlighted = index; onClicked: root.choose(index) }
			}
		}
	}

	// The question is asked here while the page is open; DisplayConfirm asks over every screen otherwise.
	Rectangle {
		anchors.fill: parent; z: 20; visible: root.display.waiting
		color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.82)
		MouseArea { anchors.fill: parent }
		DisplayConfirmCard { id: confirm; anchors.centerIn: parent; display: root.display }
		onVisibleChanged: if (visible) Qt.callLater(confirm.focusDefault)
	}
}
