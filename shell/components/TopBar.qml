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
	color: Theme.transparent

	Canvas {
		anchors.fill: parent
		onWidthChanged: requestPaint()
		onHeightChanged: requestPaint()
		onPaint: {
			const ctx = getContext("2d")
			const bottom = height - Theme.lineWidth / 2
			const shoulder = bottom - Theme.barNotchHeight
			ctx.clearRect(0, 0, width, height)
			ctx.beginPath()
			ctx.moveTo(0, shoulder)
			ctx.lineTo(Theme.barNotchShoulder, shoulder)
			ctx.lineTo(Theme.barNotchWidth, bottom)
			ctx.lineTo(width - Theme.barNotchWidth, bottom)
			ctx.lineTo(width - Theme.barNotchShoulder, shoulder)
			ctx.lineTo(width, shoulder)
			ctx.lineTo(width, 0)
			ctx.lineTo(0, 0)
			ctx.closePath()
			ctx.fillStyle = Theme.background
			ctx.fill()
			ctx.beginPath()
			ctx.moveTo(0, shoulder)
			ctx.lineTo(Theme.barNotchShoulder, shoulder)
			ctx.lineTo(Theme.barNotchWidth, bottom)
			ctx.lineTo(width - Theme.barNotchWidth, bottom)
			ctx.lineTo(width - Theme.barNotchShoulder, shoulder)
			ctx.lineTo(width, shoulder)
			ctx.strokeStyle = Theme.accentDim
			ctx.lineWidth = Theme.lineWidth
			ctx.stroke()
		}
	}
	RowLayout {
		objectName: "barLayout"
		anchors.fill: parent
		anchors.leftMargin: Theme.barPadding
		anchors.rightMargin: Theme.barPadding
		spacing: Theme.spaceXL

		HudText {
			text: "SHITTIM"
			textStyle: "title"
			color: Theme.accentBright
			Layout.alignment: Qt.AlignVCenter
			Layout.rightMargin: Theme.spaceXL
		}
		Flickable {
			objectName: "workspaceViewport"
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			Layout.preferredWidth: workspaces.implicitWidth
			Layout.maximumWidth: workspaces.implicitWidth
			Layout.preferredHeight: Theme.barWorkspaceHeight
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
			objectName: "barStatuses"
			Layout.alignment: Qt.AlignVCenter
			spacing: Theme.spaceXL
			Network { compact: true; anchors.verticalCenter: parent.verticalCenter }
			Volume { compact: true; anchors.verticalCenter: parent.verticalCenter }
			Battery { compact: true; anchors.verticalCenter: parent.verticalCenter }
			HudDivider { anchors.verticalCenter: parent.verticalCenter }
			Clock { compact: true; anchors.verticalCenter: parent.verticalCenter }
		}
	}
}
