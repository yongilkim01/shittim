import QtQuick
import Quickshell
import "../../components"

// Compile and instantiate the real 0.3.2 imports without mapping a second bar.
ShellRoot {
	TopBar { visible: false }
	ControlCenter { visible: false }
	Timer { interval: 1200; running: true; onTriggered: Qt.quit() }
}
