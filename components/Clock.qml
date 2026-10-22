import Quickshell
import QtQuick
import "../ui"

HudText {
	text: Qt.formatDateTime(systemClock.date, "yyyy-MM-dd ddd  HH:mm:ss")
	color: Theme.textPrimary

	SystemClock {
		id: systemClock
		precision: SystemClock.Seconds
	}
}
