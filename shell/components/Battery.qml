import QtQuick
import Quickshell.Services.UPower
import "../ui"

HudStatus {
	id: root

	readonly property UPowerDevice battery: UPower.displayDevice
	readonly property bool available: battery !== null && battery.ready
		&& battery.type === UPowerDeviceType.Battery && battery.isPresent
	readonly property bool validPercentage: available && isFinite(battery.percentage)
		&& battery.percentage >= 0 && battery.percentage <= 1
	readonly property int percentage: validPercentage ? Math.round(battery.percentage * 100) : 0
	readonly property bool charging: available && battery.state === UPowerDeviceState.Charging
	readonly property bool fullyCharged: available && battery.state === UPowerDeviceState.FullyCharged
	readonly property bool lowBattery: validPercentage && battery.percentage <= 0.20
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
	readonly property string status: {
		if (!available) return "N/A"
		switch (battery.state) {
		case UPowerDeviceState.Charging: return "Charging"
		case UPowerDeviceState.FullyCharged: return "Full"
		case UPowerDeviceState.PendingCharge: return "Plugged in"
		case UPowerDeviceState.PendingDischarge: return "On battery"
		case UPowerDeviceState.Empty: return "Empty"
		case UPowerDeviceState.Discharging: return "Discharging"
		default: return "Unknown"
		}
	}

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
