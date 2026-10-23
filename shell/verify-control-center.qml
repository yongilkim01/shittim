import QtQuick
import Quickshell
import "./components"

// Compile and instantiate the real 0.3.2 imports without mapping a second bar.
// Keep this entrypoint beside shell.qml: Quickshell confines imports to its config root.
ShellRoot {
	TopBar { visible: false }
	ControlCenter { visible: false }
	Timer { interval: 1200; running: true; onTriggered: Qt.quit() }
}
