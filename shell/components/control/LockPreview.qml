import QtQuick
import "../../ui"

// Small portrait preview of the hyprlock screen (config/templates/shittim-lock.conf.in): same wallpaper, clock and date.
Item {
	id: root
	property url wallpaper: ""
	property date time: new Date()
	clip: true
	Rectangle { anchors.fill: parent; color: Theme.background }
	Image {
		id: image; objectName: "lockPreviewImage"
		// Full-height 16:9 wallpaper shifted so the lit tower (about 69% across) sits in the portrait crop.
		height: parent.height; width: height * 1672 / 941
		x: Math.min(0, Math.max(parent.width - width, parent.width / 2 - width * 0.69))
		source: root.wallpaper; asynchronous: true; sourceSize.height: Math.ceil(height * 2)
	}
	HudText {
		objectName: "lockPreviewTime"
		anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.3
		text: Qt.formatTime(root.time, "HH:mm"); font.pixelSize: 26; font.letterSpacing: 2; color: Theme.textPrimary
	}
	HudText {
		anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.3 + 32
		text: Qt.formatDate(root.time, "yyyy.MM.dd"); font.pixelSize: 8; font.letterSpacing: 2; color: Theme.textSecondary
	}
	Rectangle {
		anchors.horizontalCenter: parent.horizontalCenter; y: parent.height * 0.74
		width: parent.width * 0.66; height: 16; color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8)
		border.width: 1; border.color: Theme.accentDim
	}
	Rectangle { anchors.fill: parent; color: Theme.transparent; border.width: 1; border.color: Theme.border }
	Timer { interval: 30000; running: root.visible; repeat: true; triggeredOnStart: true; onTriggered: root.time = new Date() }
}
