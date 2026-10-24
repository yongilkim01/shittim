pragma Singleton
import QtQuick

QtObject {
	readonly property string name: "SHITTIM HUD"
	readonly property color background: "#020f15"
	readonly property color surface: "#041923"
	readonly property color surfaceElevated: "#08232e"
	readonly property color accent: "#00d9f5"
	readonly property color accentBright: "#50eaff"
	readonly property color accentDim: "#08798b"
	readonly property color textPrimary: "#d5f8ff"
	readonly property color textSecondary: "#76aebc"
	readonly property color textMuted: "#477481"
	readonly property color border: "#145263"
	readonly property color borderActive: accent
	readonly property color success: "#42e3b4"
	readonly property color warning: "#ffc56b"
	readonly property color danger: "#ff637e"
	readonly property color transparent: "transparent"
	readonly property color floatingSurface: "#ed020f15"
	readonly property color selectionFill: "#3300d9f5"
	readonly property int dockIconSize: 30
	readonly property int dockCellSize: 44
	readonly property int dockHeight: 52
	readonly property int dockBottomMargin: 2
	readonly property int dockEndSpace: 48
	readonly property int desktopCellWidth: 88
	readonly property int desktopCellHeight: 92

	readonly property string fontMono: "Hack Nerd Font Mono"
	readonly property string fontKorean: "D2Coding"
	readonly property int textCaption: 10
	readonly property int textStatus: 12
	readonly property int textBody: 14
	readonly property int textTitle: 16
	readonly property int textValue: 24
	readonly property real titleTracking: 2.5
	readonly property real sectionTracking: 1.5
	readonly property int iconSize: 14

	readonly property int spaceXS: 4
	readonly property int spaceS: 8
	readonly property int spaceM: 12
	readonly property int spaceL: 16
	readonly property int spaceXL: 24
	readonly property int barHeight: 40
	readonly property int barPadding: 38
	readonly property int barNotchWidth: 24
	readonly property int barNotchShoulder: 8
	readonly property int barNotchHeight: 16
	readonly property int barWorkspaceWidth: 20
	readonly property int barWorkspaceHeight: 18
	readonly property int barWorkspaceRadius: 3
	readonly property int barTextSize: 14
	readonly property int barIconSize: 24
	readonly property int controlHeight: 28
	readonly property int workspaceWidth: 32
	readonly property int networkTextWidth: 200
	readonly property int lineWidth: 1
	readonly property int cornerLength: 8
	readonly property int cornerRadius: 1
	readonly property int progressHeight: 2
	readonly property int controlPanelWidth: 337
	readonly property int controlPanelHeight: 293
	readonly property int controlDetailHeight: 650
	readonly property int launcherWidth: 394
	readonly property int launcherHeight: 187
	readonly property int notificationWidth: 360
	readonly property int notificationHeight: 187
	readonly property int dashboardWidth: 746
	readonly property int dashboardHeight: 300
	readonly property int mediaWidth: 349
	readonly property int mediaHeight: 271

	readonly property int hoverDuration: 150
	readonly property int stateDuration: 200
	readonly property int panelDuration: 250
	readonly property int easing: Easing.OutCubic
}
