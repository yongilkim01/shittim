import QtQuick
import QtQuick.Layouts
import "../../ui"

// Portal share target chooser. Choosing is the user's consent; the view never selects on its own.
FocusScope {
	id: root
	property var outputs: []
	property var windows: []
	property bool remember: true
	property string tab: outputs.length > 0 || windows.length === 0 ? "screen" : "window"
	// Optional live preview; receives the output object as `output`.
	property Component previewComponent: null
	signal chosen(string kind, string value)
	signal cancelled()
	Keys.onEscapePressed: event => { root.cancelled(); event.accepted = true }

	HudPanel {
		anchors.fill: parent; active: true
		color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.97)
		ColumnLayout {
			anchors.fill: parent; anchors.margins: Theme.spaceL; spacing: Theme.spaceM
			RowLayout {
				Layout.fillWidth: true
				HudIcon { text: "󰍹"; color: Theme.accent }
				ColumnLayout {
					Layout.fillWidth: true; spacing: 0
					HudText { text: "SCREEN SHARE"; textStyle: "section"; color: Theme.accent }
					HudText { text: "공유할 화면이나 창을 선택하세요"; color: Theme.textPrimary }
				}
				HudButton { text: "󰅖"; onClicked: root.cancelled() }
			}
			RowLayout {
				spacing: Theme.spaceS
				HudButton { objectName: "pickerTabScreen"; text: "화면 " + root.outputs.length; active: root.tab === "screen"; onClicked: root.tab = "screen" }
				HudButton { objectName: "pickerTabWindow"; text: "창 " + root.windows.length; active: root.tab === "window"; onClicked: root.tab = "window" }
			}
			HudDivider { vertical: false; Layout.fillWidth: true }
			Flickable {
				id: viewport; Layout.fillWidth: true; Layout.fillHeight: true; clip: true
				contentWidth: width; contentHeight: root.tab === "screen" ? screens.implicitHeight : windowList.implicitHeight
				boundsBehavior: Flickable.StopAtBounds
				GridLayout {
					id: screens; visible: root.tab === "screen"; width: viewport.width
					columns: Math.max(1, Math.floor(viewport.width / 240)); columnSpacing: Theme.spaceM; rowSpacing: Theme.spaceM
					Repeater {
						model: root.outputs
						Rectangle {
							id: screenCard
							required property var modelData
							required property int index
							objectName: "pickerScreen-" + modelData.name
							Layout.fillWidth: true; Layout.preferredHeight: 170
							color: screenInput.hovered || screenInput.focused ? Theme.surfaceElevated : Theme.surface
							border.width: Theme.lineWidth; border.color: screenInput.hovered || screenInput.focused ? Theme.borderActive : Theme.border
							radius: Theme.cornerRadius
							Rectangle {
								id: previewFrame; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Theme.spaceS
								height: parent.height - 48; color: Theme.background; border.color: Theme.border; border.width: Theme.lineWidth
								HudIcon { anchors.centerIn: parent; text: "󰍹"; font.pixelSize: 40; color: Theme.accentDim; visible: preview.item === null }
								Loader {
									id: preview; anchors.fill: parent; anchors.margins: Theme.lineWidth
									active: root.previewComponent !== null
									sourceComponent: root.previewComponent
									onLoaded: item.output = screenCard.modelData
								}
							}
							HudText {
								anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Theme.spaceS
								text: modelData.name + "  ·  " + modelData.width + "×" + modelData.height
								color: screenInput.hovered || screenInput.focused ? Theme.accentBright : Theme.textPrimary
							}
							ActionInput { id: screenInput; label: "화면 공유: " + screenCard.modelData.name; focus: screenCard.index === 0 && root.tab === "screen"; onTriggered: root.chosen("screen", screenCard.modelData.name) }
						}
					}
				}
				ColumnLayout {
					id: windowList; visible: root.tab === "window"; width: viewport.width; spacing: Theme.spaceXS
					Repeater {
						model: root.windows
						Rectangle {
							id: windowRow
							required property var modelData
							required property int index
							objectName: "pickerWindow-" + modelData.id
							Layout.fillWidth: true; implicitHeight: 44
							color: windowInput.hovered || windowInput.focused ? Theme.surfaceElevated : Theme.surface
							border.width: Theme.lineWidth; border.color: windowInput.hovered || windowInput.focused ? Theme.borderActive : Theme.border
							radius: Theme.cornerRadius
							RowLayout {
								anchors.fill: parent; anchors.leftMargin: Theme.spaceM; anchors.rightMargin: Theme.spaceM; spacing: Theme.spaceM
								HudIcon { text: "󰖯"; color: Theme.accent }
								HudText { text: windowRow.modelData.title || windowRow.modelData.appClass; Layout.fillWidth: true; elide: Text.ElideRight; color: Theme.textPrimary }
								HudText { text: windowRow.modelData.appClass; textStyle: "caption"; Layout.maximumWidth: 160; elide: Text.ElideRight }
							}
							ActionInput { id: windowInput; label: "창 공유: " + (windowRow.modelData.title || windowRow.modelData.appClass); focus: windowRow.index === 0 && root.tab === "window"; onTriggered: root.chosen("window", windowRow.modelData.id) }
						}
					}
				}
			}
			HudText {
				visible: root.tab === "screen" ? root.outputs.length === 0 : root.windows.length === 0
				text: root.tab === "screen" ? "공유할 수 있는 화면이 없습니다." : "공유할 수 있는 창이 없습니다."; color: Theme.textMuted
			}
			HudDivider { vertical: false; Layout.fillWidth: true }
			RowLayout {
				Layout.fillWidth: true
				HudButton { objectName: "pickerRemember"; text: root.remember ? "󰄵" : "󰄱"; active: root.remember; onClicked: root.remember = !root.remember }
				HudText {
					Layout.fillWidth: true; wrapMode: Text.WordWrap; maximumLineCount: 2; textStyle: "caption"
					text: "같은 앱이 이 공유를 다시 요청하면 이 선택을 그대로 사용 (Chrome 공유 창에서 다시 묻지 않음)"
				}
				HudButton { text: "취소"; onClicked: root.cancelled() }
			}
		}
	}
}
