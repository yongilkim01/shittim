import Quickshell
import "./components"

ShellRoot {
	Variants {
		model: Quickshell.screens
		TopBar {
			required property var modelData
			screen: modelData
		}
	}
	ControlCenter {}
	AppLauncher {}
	NotificationCenter {}
	NotificationPopups {}
	SystemDashboard {}
}
