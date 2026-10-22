import Quickshell
import QtQuick
import QtQuick.Layouts
import "../ui"

PanelWindow {
	id: bar
	anchors {
		top: true
		left: true
		right: true
	}

	implicitHeight: Theme.barHeight
	color: Theme.background

	HudPanel {
		anchors.fill: parent
		color: Theme.background
		border.width: 0
		corners: false
	}
	Rectangle {
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		height: Theme.lineWidth
		color: Theme.accentDim
	}
	RowLayout {
		anchors.fill: parent
		anchors.leftMargin: Theme.barPadding
		anchors.rightMargin: Theme.barPadding
		spacing: Theme.spaceM

		Row {
			spacing: Theme.spaceS
			Layout.alignment: Qt.AlignVCenter
			HudPanel {
				width: Theme.spaceXL
				height: Theme.spaceXL
				active: true
				anchors.verticalCenter: parent.verticalCenter
				HudIcon {
					anchors.centerIn: parent
					text: "\uf2db"
					color: Theme.accent
				}
			}
			HudText {
				text: "SHITTIM"
				textStyle: "title"
				font.pixelSize: Theme.textBody
				color: Theme.accent
				anchors.verticalCenter: parent.verticalCenter
			}
		}
		HudDivider { Layout.alignment: Qt.AlignVCenter }
		Flickable {
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			Layout.preferredWidth: workspaces.implicitWidth
			Layout.maximumWidth: workspaces.implicitWidth
			Layout.preferredHeight: Theme.controlHeight
			Layout.alignment: Qt.AlignVCenter
			contentWidth: workspaces.width
			contentHeight: workspaces.height
			flickableDirection: Flickable.HorizontalFlick
			boundsBehavior: Flickable.StopAtBounds
			clip: true
			Workspaces { id: workspaces }
		}
		Item { Layout.fillWidth: true; Layout.minimumWidth: Theme.spaceS }
		Row {
			Layout.alignment: Qt.AlignVCenter
			spacing: Theme.spaceS
			Network { anchors.verticalCenter: parent.verticalCenter }
			HudDivider { anchors.verticalCenter: parent.verticalCenter }
			Volume { anchors.verticalCenter: parent.verticalCenter }
			HudDivider { visible: battery.visible; anchors.verticalCenter: parent.verticalCenter }
			Battery { id: battery; anchors.verticalCenter: parent.verticalCenter }
			HudDivider { anchors.verticalCenter: parent.verticalCenter }
			Clock { anchors.verticalCenter: parent.verticalCenter }
		}
	}
}
