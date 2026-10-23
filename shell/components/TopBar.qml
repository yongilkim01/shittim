import Quickshell
import QtQuick
import QtQuick.Layouts
import "../ui"
import "../services"

PanelWindow {
	id: bar
	anchors {
		top: true
		left: true
		right: true
	}

	implicitHeight: Theme.barHeight
	color: Theme.transparent
	TapHandler {
		onTapped: {
			if (ControlState.opened && point.position.x < statusArea.mapToItem(null, 0, 0).x) ControlState.close()
			const notificationX = notificationArea.mapToItem(null, 0, 0).x
			if (NotificationState.opened && (point.position.x < notificationX || point.position.x > notificationX + notificationArea.width)) NotificationState.close()
		}
	}

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
		Item {
			id: notificationArea
			Layout.preferredWidth: notificationStatus.implicitWidth
			Layout.preferredHeight: Theme.barIconSize
			Layout.alignment: Qt.AlignVCenter
			Row {
				id: notificationStatus; spacing: Theme.spaceXS
				HudIcon {
					text: NotificationState.dnd ? "\uf1f6" : "\uf0f3"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize
					color: NotificationState.ownership === "conflict" || NotificationState.ownership === "error" ? Theme.warning
						: NotificationState.unread > 0 || NotificationState.dnd ? Theme.accent : Theme.textSecondary
				}
				HudText { visible: NotificationState.unread > 0; text: NotificationState.unread > 99 ? "99+" : String(NotificationState.unread); font.pixelSize: 10; height: Theme.barIconSize; color: Theme.accentBright }
			}
			MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: NotificationState.toggle(bar) }
		}
		Item {
			id: statusArea
			implicitWidth: statuses.implicitWidth
			implicitHeight: statuses.implicitHeight
			Layout.alignment: Qt.AlignVCenter
			MouseArea {
				anchors.fill: parent; cursorShape: Qt.PointingHandCursor
				onClicked: ControlState.toggle(bar)
			}
			Row {
				id: statuses; objectName: "barStatuses"
				spacing: Theme.spaceXL
				Network { compact: true; anchors.verticalCenter: parent.verticalCenter }
				Volume { compact: true; anchors.verticalCenter: parent.verticalCenter; onControlCenterRequested: ControlState.toggle(bar) }
				Battery { compact: true; anchors.verticalCenter: parent.verticalCenter }
				HudDivider { anchors.verticalCenter: parent.verticalCenter }
				Clock { compact: true; anchors.verticalCenter: parent.verticalCenter }
			}
		}
	}
}
