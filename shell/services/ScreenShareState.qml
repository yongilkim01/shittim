pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import "../core/DeviceData.js" as Devices

// Observation only: the portal creates a stream after the user picks a target and removes it when sharing stops.
// Starting or stopping a share stays with the sharing application and the portal picker.
Scope {
	readonly property var streams: Pipewire.nodes.values.filter(node => Devices.isScreenCast(node))
	readonly property int count: streams.length
	readonly property bool active: count > 0
}
