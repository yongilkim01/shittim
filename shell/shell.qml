//@ pragma IconTheme Shittim-HUD
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
	Variants {
		model: Quickshell.screens
		DesktopDock {}
	}
	Variants {
		model: Quickshell.screens
		DesktopSurface {}
	}
	AppLauncher {}
	NotificationCenter {}
	NotificationPopups {}
	SystemDashboard {}
	AppMediaControls {}
	WindowManager {}
	SnapPreview {}
}
