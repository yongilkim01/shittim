import QtQuick
import Quickshell.Services.UPower
import "../ui"
import "../services"

HudStatus {
	id: root

	readonly property UPowerDevice battery: BatteryState.battery
	readonly property bool available: BatteryState.available
	readonly property bool validPercentage: BatteryState.validPercentage
	readonly property int percentage: BatteryState.percentage
	readonly property bool charging: BatteryState.charging
	readonly property bool fullyCharged: BatteryState.fullyCharged
	readonly property bool lowBattery: BatteryState.lowBattery
	readonly property string icon: {
		if (charging) return "\uf0e7"
		if (fullyCharged) return "\uf240"
		if (!validPercentage) return "\uf244"
		if (battery.percentage >= 0.90) return "\uf240"
		if (battery.percentage >= 0.60) return "\uf241"
		if (battery.percentage >= 0.40) return "\uf242"
		if (battery.percentage > 0.20) return "\uf243"
		return "\uf244"
	}
	readonly property string status: BatteryState.status

	visible: available
	glyph: icon
	text: !available ? ""
		: (validPercentage ? percentage + "%" : "--%")
			+ (!compact || hovered ? (lowBattery ? " LOW" : "") + (status.length > 0 ? " " + status : "") : "")
	color: lowBattery ? Theme.danger : (compact ? Theme.accentBright
		: (charging || fullyCharged ? Theme.success : Theme.textPrimary))
	HudProgress {
		visible: !root.compact || root.hovered
		anchors.left: parent.left
		anchors.right: parent.right
		anchors.bottom: parent.bottom
		anchors.leftMargin: Theme.spaceXS
		anchors.rightMargin: Theme.spaceXS
		value: root.validPercentage ? root.battery.percentage : 0
		fillColor: root.lowBattery ? Theme.danger : Theme.accentDim
	}
}
