import Quickshell
import QtQuick
import "../ui"

HudText {
	property bool compact: false
	font.pixelSize: compact ? Theme.barTextSize : Theme.textStatus
	text: Qt.formatDateTime(systemClock.date, compact ? "MM/dd HH:mm" : "yyyy-MM-dd ddd  HH:mm:ss")
	color: Theme.textPrimary

	SystemClock {
		id: systemClock
		precision: SystemClock.Seconds
	}
}
