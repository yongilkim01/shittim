import QtQuick
import QtQuick.Layouts
import "../../ui"
import "../control"

// Portal share target chooser: pick a monitor or a window, then «공유 시작» (or activate the picked card again).
// Choosing is the user's consent; nothing is selected or shared automatically.
FocusScope {
	id: root
	property var outputs: []
	property var windows: []
	property string focusedOutput: ""
	// Restore-token consent; follows xdph allow_token_by_default (no separate control in this layout).
	property bool remember: true
	property string tab: outputs.length > 0 || windows.length === 0 ? "screen" : "window"
	// Optional live preview; receives `kind` ("screen" | "window") and `target` (the list entry).
	property Component previewComponent: null
	// Optional desktop-entry lookup for window cards: appClass -> {name, genericName, icon} or null.
	property var appInfo: null
	property string selectedKind: ""
	property string selectedValue: ""
	readonly property bool hasSelection: selectedValue.length > 0
	signal chosen(string kind, string value)
	signal cancelled()

	function select(kind, value) {
		// A second activation of the picked card shortly after the first works as a double click.
		if (selectedKind === kind && selectedValue === value && repeatWindow.running) { share(); return }
		selectedKind = kind; selectedValue = value
		repeatWindow.restart()
	}
	function share() { if (hasSelection) chosen(selectedKind, selectedValue) }
	function aspect(width, height) {
		const ratio = width / height
		for (const known of [[16, 9], [16, 10], [21, 9], [4, 3], [3, 2], [5, 4]])
			if (Math.abs(ratio - known[0] / known[1]) < 0.02) return known[0] + ":" + known[1]
		return ""
	}
	function screenTitle(entry, index) { return "모니터 " + (index + 1) }
	function screenDetail(entry) {
		const ratio = aspect(entry.width, entry.height)
		return entry.width + " × " + entry.height + (ratio ? " (" + ratio + ")" : "")
	}
	function info(entry) {
		const found = typeof appInfo === "function" ? appInfo(entry.appClass) : null
		return found || {name: "", genericName: "", icon: ""}
	}
	function windowTitle(entry) { return info(entry).name || entry.appClass || "제목 없는 창" }
	// The window title tells apart several windows of one app; the app kind is shown otherwise.
	function windowDetail(entry) {
		const siblings = windows.filter(other => other.appClass === entry.appClass).length
		return siblings === 1 && info(entry).genericName ? info(entry).genericName : entry.title || entry.appClass
	}
	readonly property string message: !hasSelection ? "공유할 화면이나 창을 선택하세요."
		: selectedKind === "screen" ? "선택한 화면만 공유됩니다." : "선택한 창만 공유됩니다. 다른 창은 보이지 않습니다."
	Timer { id: repeatWindow; interval: 500 }
	Keys.onEscapePressed: event => { root.cancelled(); event.accepted = true }

	ControlFrame {
		anchors.fill: parent; cut: 16
		fillColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.98)
		gradientColor: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
		strokeColor: Theme.accentDim
	}
	ColumnLayout {
		anchors.fill: parent; anchors.margins: Theme.spaceXL; spacing: Theme.spaceL

		RowLayout {
			Layout.fillWidth: true
			ColumnLayout {
				Layout.fillWidth: true; spacing: Theme.spaceXS
				HudText { text: "화면 공유"; font.pixelSize: 22; font.bold: true; color: Theme.textPrimary }
				HudText { text: "공유할 화면 또는 창을 선택하세요"; color: Theme.textSecondary }
			}
			Item { Layout.fillWidth: true }
			Item {
				Layout.alignment: Qt.AlignTop; implicitWidth: 32; implicitHeight: 32
				HudIcon { anchors.centerIn: parent; text: "󰅖"; font.pixelSize: 22; color: closeInput.hovered || closeInput.focused ? Theme.accentBright : Theme.textSecondary }
				ActionInput { id: closeInput; label: "닫기"; onTriggered: root.cancelled() }
			}
		}

		Rectangle {
			Layout.fillWidth: true; implicitHeight: 64
			color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.6)
			border.width: Theme.lineWidth; border.color: Theme.border
			RowLayout {
				anchors.fill: parent; spacing: 0
				Repeater {
					model: [{key: "screen", icon: "󰍹", title: "전체 화면", count: root.outputs.length},
						{key: "window", icon: "󰖯", title: "애플리케이션 창", count: root.windows.length}]
					Item {
						id: segment
						required property var modelData
						required property int index
						objectName: modelData.key === "screen" ? "pickerTabScreen" : "pickerTabWindow"
						readonly property bool current: root.tab === modelData.key
						Layout.fillWidth: true; Layout.fillHeight: true
						Rectangle { anchors.fill: parent; color: segmentInput.hovered ? Theme.surfaceElevated : Theme.transparent }
						RowLayout {
							anchors.centerIn: parent; spacing: Theme.spaceM
							HudIcon { text: segment.modelData.icon; font.pixelSize: 30; color: segment.current ? Theme.accent : Theme.textSecondary }
							HudText { text: segment.modelData.title; font.pixelSize: Theme.textBody; font.bold: segment.current; color: segment.current ? Theme.accentBright : Theme.textSecondary }
						}
						Rectangle { visible: segment.index === 0; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: Theme.lineWidth; height: parent.height - Theme.spaceL * 2; color: Theme.border }
						Rectangle {
							visible: segment.current; anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
							anchors.leftMargin: Theme.spaceL; anchors.rightMargin: Theme.spaceL; height: 3; color: Theme.accent
						}
						ActionInput { id: segmentInput; label: segment.modelData.title + " " + segment.modelData.count + "개"; onTriggered: root.tab = segment.modelData.key }
					}
				}
			}
		}

		// Whole screens: monitors on the left, the open windows alongside for a quick window pick.
		RowLayout {
			visible: root.tab === "screen"; Layout.fillWidth: true; Layout.fillHeight: true; spacing: Theme.spaceL
			ColumnLayout {
				Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 62; spacing: Theme.spaceM
				HudText { text: "모니터 선택"; font.pixelSize: Theme.textBody; font.bold: true; color: Theme.textPrimary }
				Flickable {
					id: monitorView; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
					contentWidth: width; contentHeight: monitors.implicitHeight; boundsBehavior: Flickable.StopAtBounds
					GridLayout {
						id: monitors; width: monitorView.width; columns: 2; columnSpacing: Theme.spaceL; rowSpacing: Theme.spaceL
						readonly property real cardWidth: (width - columnSpacing) / 2
						Repeater {
							model: root.outputs
							Item {
								id: monitor
								required property var modelData
								required property int index
								readonly property bool picked: root.selectedKind === "screen" && root.selectedValue === modelData.name
								objectName: "pickerScreen-" + modelData.name
								Layout.preferredWidth: monitors.cardWidth; Layout.preferredHeight: thumb.height + labels.implicitHeight + Theme.spaceS
								SharePreview {
									id: thumb; width: parent.width; height: Math.round(width * 9 / 16)
									kind: "screen"; target: monitor.modelData; component: root.previewComponent
									picked: monitor.picked; highlighted: monitorInput.hovered || monitorInput.focused; placeholder: "󰍹"
								}
								Column {
									id: labels; anchors.top: thumb.bottom; anchors.topMargin: Theme.spaceS; anchors.horizontalCenter: parent.horizontalCenter; spacing: 2
									HudText { anchors.horizontalCenter: parent.horizontalCenter; text: root.screenTitle(monitor.modelData, monitor.index); font.bold: true; color: monitor.picked ? Theme.accentBright : Theme.textPrimary }
									HudText { anchors.horizontalCenter: parent.horizontalCenter; text: root.screenDetail(monitor.modelData); textStyle: "caption"; color: Theme.textSecondary }
								}
								ActionInput {
									id: monitorInput
									label: root.screenTitle(monitor.modelData, monitor.index) + " (" + monitor.modelData.name + (monitor.modelData.name === root.focusedOutput ? ", 지금 보고 있는 화면" : "") + ")"
									focus: monitor.index === 0; onTriggered: root.select("screen", monitor.modelData.name)
								}
							}
						}
					}
				}
			}
			Rectangle { Layout.fillHeight: true; width: Theme.lineWidth; color: Theme.border }
			ColumnLayout {
				Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 38; spacing: Theme.spaceM
				HudText { text: "애플리케이션 창 미리보기"; font.pixelSize: Theme.textBody; font.bold: true; color: Theme.textPrimary }
				Flickable {
					id: sideView; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
					contentWidth: width; contentHeight: sideList.implicitHeight; boundsBehavior: Flickable.StopAtBounds
					ColumnLayout {
						id: sideList; width: sideView.width; spacing: Theme.spaceM
						Repeater {
							model: root.windows
							Item {
								id: row
								required property var modelData
								readonly property bool picked: root.selectedKind === "window" && root.selectedValue === modelData.id
								objectName: "pickerWindowRow-" + modelData.id
								Layout.fillWidth: true; implicitHeight: 84
								SharePreview {
									id: rowThumb; width: Math.min(150, parent.width * 0.55); height: parent.height
									kind: "window"; target: row.modelData; component: root.previewComponent
									picked: row.picked; highlighted: rowInput.hovered || rowInput.focused; placeholder: "󰖯"; badge: false
								}
								AppLabel {
									anchors.left: rowThumb.right; anchors.leftMargin: Theme.spaceM; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
									icon: root.info(row.modelData).icon; title: root.windowTitle(row.modelData); detail: root.windowDetail(row.modelData); picked: row.picked
								}
								ActionInput { id: rowInput; label: "창 선택: " + root.windowTitle(row.modelData) + " — " + row.modelData.title; onTriggered: root.select("window", row.modelData.id) }
							}
						}
					}
				}
				HudText { visible: root.windows.length === 0; text: "열린 창이 없습니다."; color: Theme.textMuted }
			}
		}

		// Single windows: larger previews.
		Flickable {
			id: windowView; visible: root.tab === "window"; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
			contentWidth: width; contentHeight: windowGrid.implicitHeight; boundsBehavior: Flickable.StopAtBounds
			GridLayout {
				id: windowGrid; width: windowView.width; columns: 3; columnSpacing: Theme.spaceL; rowSpacing: Theme.spaceL
				readonly property real cardWidth: (width - columnSpacing * 2) / 3
				Repeater {
					model: root.windows
					Item {
						id: card
						required property var modelData
						required property int index
						readonly property bool picked: root.selectedKind === "window" && root.selectedValue === modelData.id
						objectName: "pickerWindow-" + modelData.id
						Layout.preferredWidth: windowGrid.cardWidth; Layout.preferredHeight: cardThumb.height + 48
						SharePreview {
							id: cardThumb; width: parent.width; height: Math.round(width * 10 / 16)
							kind: "window"; target: card.modelData; component: root.previewComponent
							picked: card.picked; highlighted: cardInput.hovered || cardInput.focused; placeholder: "󰖯"
						}
						AppLabel {
							anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
							icon: root.info(card.modelData).icon; title: root.windowTitle(card.modelData); detail: card.modelData.title || card.modelData.appClass; picked: card.picked
						}
						ActionInput { id: cardInput; label: "창 선택: " + root.windowTitle(card.modelData) + " — " + card.modelData.title; focus: card.index === 0; onTriggered: root.select("window", card.modelData.id) }
					}
				}
			}
		}
		HudText {
			objectName: "pickerEmpty"
			visible: root.tab === "screen" ? root.outputs.length === 0 : root.windows.length === 0
			Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; color: Theme.textMuted
			text: root.tab === "screen" ? "공유할 수 있는 화면이 없습니다." : "공유할 수 있는 창이 없습니다. 공유할 앱을 먼저 여세요."
		}

		Rectangle { Layout.fillWidth: true; height: Theme.lineWidth; color: Theme.border }
		RowLayout {
			Layout.fillWidth: true; spacing: Theme.spaceL
			Rectangle {
				Layout.fillWidth: true; implicitHeight: 48; radius: 4
				color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.06); border.width: Theme.lineWidth; border.color: Theme.accentDim
				RowLayout {
					anchors.fill: parent; anchors.leftMargin: Theme.spaceL; anchors.rightMargin: Theme.spaceL; spacing: Theme.spaceM
					HudIcon { text: "󰋽"; font.pixelSize: 22; color: Theme.accent }
					HudText { objectName: "pickerInfo"; text: root.message; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.accentBright }
				}
			}
			Rectangle {
				implicitWidth: 112; implicitHeight: 48; radius: 4
				color: cancelInput.hovered || cancelInput.focused ? Theme.surfaceElevated : Theme.transparent
				border.width: Theme.lineWidth; border.color: cancelInput.hovered || cancelInput.focused ? Theme.borderActive : Theme.textSecondary
				HudText { anchors.centerIn: parent; text: "취소"; font.pixelSize: Theme.textBody; color: Theme.textPrimary }
				ActionInput { id: cancelInput; label: "취소"; onTriggered: root.cancelled() }
			}
			Rectangle {
				id: shareButton; objectName: "pickerShare"
				enabled: root.hasSelection
				implicitWidth: 132; implicitHeight: 48; radius: 4
				color: !enabled ? Theme.surface : shareInput.hovered || shareInput.focused ? Theme.accentBright : Theme.accent
				border.width: Theme.lineWidth; border.color: enabled ? Theme.accentBright : Theme.border
				HudText { anchors.centerIn: parent; text: "공유 시작"; font.pixelSize: Theme.textBody; font.bold: true; color: shareButton.enabled ? Theme.background : Theme.textMuted }
				ActionInput { id: shareInput; label: "선택한 대상 공유 시작"; onTriggered: root.share() }
			}
		}
	}
}
