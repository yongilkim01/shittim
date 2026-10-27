//@ pragma IconTheme Shittim-HUD
import Quickshell
import "./components"
import "./services"
import QtQuick

ShellRoot {
	readonly property string runtimeContract:RuntimeStatus.contract
	Connections { target:ApplicationsState;function onActivating(){InteractionState.dismiss("action")} }
	Connections { target:CaptureState;function onStarting(){InteractionState.dismiss("action")} }
	Connections { target:NetworkState;function onEditorOpening(){InteractionState.dismiss("action")} }
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
	TitlebarTooltip {}
	ActionFeedback {}
}
