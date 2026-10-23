pragma Singleton
import QtQuick
import Quickshell.Services.UPower

QtObject {
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

}
