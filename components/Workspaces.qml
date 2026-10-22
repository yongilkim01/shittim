import QtQuick
import Quickshell.Hyprland

Row{
	spacing: 6

	Repeater{
		model: Hyprland.workspaces

		delegate: Rectangle {
			id: workspaceButton

			required property HyprlandWorkspace modelData

			width: 32
			height: 28
			radius: 6

			color: modelData.focused ? "#89b4fa" : "313244"
			Text {
				anchors.centerIn: parent
				text: workspaceButton.modelData.name
				color: workspaceButton.modelData.focused ? "#11111b" : "#cdd6f4"
				font.pixelSize: 13
				font.bold: true
			}	

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor

				onClicked: workspaceButton.modelData.activate()
			}
		}
	}
}
