import Quickshell
import QtQuick

PanelWindow {
	anchors {
		top: true
		left: true
		right: true
	}

	implicitHeight: 40
	color: "#1e1e2e"

	Row {
		anchors.right: parent.right
		anchors.rightMargin: 16
		anchors.verticalCenter: parent.verticalCenter
		spacing: 16

		Battery {
			anchors.verticalCenter: parent.verticalCenter
		}

		Clock {
			color: "#cdd6f4"
			anchors.verticalCenter: parent.verticalCenter
		}
	}

	Row {
		anchors.left: parent.left
		anchors.leftMargin: 16
		anchors.verticalCenter: parent.verticalCenter
		spacing: 20
		
		Text {
			text: "Shittim"
			color: "#ffffff"
			font.pixelSize: 16
			font.bold: true
			font.family: "Hack Nerd Font Mono"
			anchors.verticalCenter: parent.verticalCenter
		}

		Workspaces {
			anchors.verticalCenter: parent.verticalCenter
		}
	}
}
