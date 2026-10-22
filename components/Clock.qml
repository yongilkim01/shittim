import Quickshell
import QtQuick

Text {
	text: Qt.formatDateTime(systemClock.date, "yyyy-MM-dd ddd  HH:mm:ss")
	color: "#ffffff"
	font.pixelSize: 14
	font.family: "Hack Nerd Font Mono"

	SystemClock {
		id: systemClock
		precision: SystemClock.Seconds
	}
}
