//@ pragma ShellId shittim-share-picker
//@ pragma IconTheme Shittim-HUD
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "./components/sharepicker"
import "./components/sharepicker/PickerData.js" as PickerData

// xdg-desktop-portal-hyprland custom picker, started per request by scripts/share-picker.sh.
// The selection goes to SHITTIM_PICKER_OUTPUT; the wrapper prints it for the portal.
ShellRoot {
	id: root
	readonly property string outputPath: Quickshell.env("SHITTIM_PICKER_OUTPUT") || ""
	readonly property var listedOutputs: PickerData.parseOutputs(Quickshell.env("XDPH_OUTPUT_SHARING_LIST") || "")
	// xdph v1.4.x does not pass outputs; the picker then lists the compositor's screens itself.
	readonly property var outputs: listedOutputs.length > 0 ? listedOutputs
		: Quickshell.screens.map(screen => ({name: screen.name, x: screen.x, y: screen.y, width: screen.width, height: screen.height}))
	readonly property var windows: PickerData.parseWindows(Quickshell.env("XDPH_WINDOW_SHARING_LIST") || "")
	property bool finished: false
	function finish(text) {
		if (finished) return
		finished = true
		if (outputPath.length > 0 && text.length > 0) result.setText(text)
		else Qt.quit()
	}
	FileView { id: result; path: root.outputPath; blockWrites: true; onSaved: Qt.quit(); onSaveFailed: Qt.quit() }
	PanelWindow {
		screen: Quickshell.screens.find(candidate => Hyprland.focusedMonitor !== null && candidate.name === Hyprland.focusedMonitor.name) || Quickshell.screens[0]
		anchors { top: true; bottom: true; left: true; right: true }
		color: "#b3020f15"
		exclusionMode: ExclusionMode.Ignore
		WlrLayershell.namespace: "shittim-share-picker"
		WlrLayershell.layer: WlrLayer.Overlay
		WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
		MouseArea { anchors.fill: parent; onClicked: root.finish("[CANCEL]\n") }
		SharePickerView {
			anchors.centerIn: parent
			width: Math.min(parent.width - 32, 980); height: Math.min(parent.height - 32, 620)
			focus: true
			outputs: root.outputs; windows: root.windows
			focusedOutput: Hyprland.focusedMonitor !== null ? Hyprland.focusedMonitor.name : ""
			remember: Quickshell.env("SHITTIM_PICKER_ALLOW_TOKEN") === "1"
			previewComponent: preview
			appInfo: appClass => root.appInfo(appClass)
			onChosen: (kind, value) => root.finish(PickerData.selection(kind, value, remember))
			onCancelled: root.finish("[CANCEL]\n")
			// Clicks inside the panel must not reach the cancel backdrop.
			MouseArea { anchors.fill: parent; z: -1 }
		}
	}
	// xdph passes the Hyprland window address as a decimal number; Quickshell reports it in hex.
	function toplevelFor(target) {
		const address = Number(target.address)
		if (!Number.isSafeInteger(address) || address <= 0) return null
		const hex = address.toString(16)
		const match = Hyprland.toplevels.values.find(toplevel => String(toplevel.address).replace(/^0x/, "").toLowerCase() === hex)
		return match ? match.wayland : null
	}
	function appInfo(appClass) {
		const entry = appClass ? DesktopEntries.heuristicLookup(appClass) : null
		if (!entry) return null
		return {name: entry.name || "", genericName: entry.genericName || "", icon: entry.icon ? Quickshell.iconPath(entry.icon, true) : ""}
	}
	Component {
		id: preview
		Item {
			property string kind: ""
			property var target: null
			readonly property bool hasContent: copy.hasContent
			ScreencopyView {
				id: copy; anchors.centerIn: parent
				width: Math.min(parent.width, implicitWidth); height: Math.min(parent.height, implicitHeight)
				constraintSize: Qt.size(parent.width, parent.height)
				captureSource: parent.target === null ? null
					: parent.kind === "screen" ? Quickshell.screens.find(screen => screen.name === parent.target.name) || null
					: root.toplevelFor(parent.target)
				live: false
			}
		}
	}
}
