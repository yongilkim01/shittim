import Quickshell
import QtQuick
import QtQuick.Layouts
import "../ui"
import "../services"
import "./media"

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
		onTapped: InteractionState.anchorTapped(bar,point.position)
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
			// Bright accents on the two notch bevels; the long edge stays dim.
			ctx.beginPath()
			ctx.moveTo(0, shoulder); ctx.lineTo(Theme.barNotchShoulder, shoulder); ctx.lineTo(Theme.barNotchWidth, bottom); ctx.lineTo(Theme.barNotchWidth + Theme.windowAccent, bottom)
			ctx.moveTo(width, shoulder); ctx.lineTo(width - Theme.barNotchShoulder, shoulder); ctx.lineTo(width - Theme.barNotchWidth, bottom); ctx.lineTo(width - Theme.barNotchWidth - Theme.windowAccent, bottom)
			ctx.strokeStyle = Theme.accent
			ctx.lineWidth = Theme.accentLineWidth
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
			id: logo
			text: "SHITTIM"
			textStyle: "title"
			color: Theme.accentBright
			Layout.alignment: Qt.AlignVCenter
			Layout.rightMargin: Theme.spaceXL
			ActionInput {label:"시스템 대시보드";focusFrame:true;onTriggered:DashboardState.toggle(bar,logo)}
		}
		Flickable {
			objectName: "workspaceViewport"
			Layout.fillWidth: true
			Layout.minimumWidth: 0
			Layout.preferredWidth: workspaces.implicitWidth
			Layout.maximumWidth: workspaces.implicitWidth
			Layout.preferredHeight: Theme.minimumTarget
			Layout.alignment: Qt.AlignVCenter
			contentWidth: workspaces.width
			contentHeight: height
			flickableDirection: Flickable.HorizontalFlick
			boundsBehavior: Flickable.StopAtBounds
			clip: true
			Workspaces { id: workspaces;y:(parent.height-height)/2 }
		}
		Item { Layout.fillWidth: true; Layout.minimumWidth: Theme.spaceS }
		MediaButton {
			objectName:"bar-window-list"
			icon:"\uf24d";tooltipText:"열린 창 목록 · Alt+Tab"
			Layout.preferredWidth:Theme.minimumTarget;Layout.preferredHeight:Theme.minimumTarget
			onClicked:WindowState.show([],0,bar.screen)
		}
		HudIcon {
			id: mediaArea
			text: "\uf001"; font.pixelSize: Theme.barIconSize; width: Theme.barIconSize
			color: MediaState.opened || MediaState.model.playing ? Theme.accent : Theme.textSecondary
			Layout.alignment: Qt.AlignVCenter
			Layout.preferredWidth: Theme.barIconSize
			Layout.preferredHeight: Theme.barIconSize
			ActionInput {label:"미디어";focusFrame:true;contextEnabled:true;onTriggered:MediaState.toggle(bar,mediaArea);onContextRequested:WindowState.show([],0,bar.screen)}
		}
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
			ActionInput {label:"알림 센터";focusFrame:true;onTriggered:NotificationState.toggle(bar,notificationArea)}
		}
		Item {
			id: statusArea
			implicitWidth: statuses.implicitWidth
			implicitHeight: statuses.implicitHeight
			Layout.alignment: Qt.AlignVCenter
			ActionInput {label:"빠른 설정";focusFrame:true;onTriggered:ControlState.toggle(bar,statusArea)}
			Row {
				id: statuses; objectName: "barStatuses"
				spacing: Theme.spaceXL
				DeviceActivity {
					id: deviceActivity
					anchors.verticalCenter: parent.verticalCenter
					microphone: MicrophoneState; camera: CameraState; screenShare: ScreenShareState; idle: PowerPolicyState
					iconFor: name => { const entry = DesktopEntries.heuristicLookup(name); return entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "" }
					onDetailsRequested: ControlState.show(bar, statusArea, "devices")
				}
				Network { compact: true; anchors.verticalCenter: parent.verticalCenter }
				Volume { compact: true; anchors.verticalCenter: parent.verticalCenter; onControlCenterRequested: ControlState.toggle(bar,statusArea) }
				Battery { compact: true; anchors.verticalCenter: parent.verticalCenter }
				HudDivider { anchors.verticalCenter: parent.verticalCenter }
				Clock { compact: true; anchors.verticalCenter: parent.verticalCenter }
			}
			BarTooltip { target: deviceActivity.hoveredItem; card: deviceActivity.card }
		}
	}
}
