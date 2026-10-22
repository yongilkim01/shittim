import QtQuick
import Quickshell.Hyprland
import "../ui"

Row{
	spacing: Theme.spaceXS

	Repeater{
		model: Hyprland.workspaces

		delegate: HudButton {
			id: workspaceButton

			required property HyprlandWorkspace modelData

			active: modelData.focused
			text: workspaceButton.modelData.name
			onClicked: workspaceButton.modelData.activate()
		}
	}
}
