pragma Singleton
import QtQuick

QtObject {
	id: root
	property bool opened: false
	property var anchorWindow: null
	property string page: "overview"
	onAnchorWindowChanged: if (anchorWindow === null) close()
	function close() { opened = false; page = "overview" }
	function toggle(window) {
		if (opened && anchorWindow === window) { close(); return }
		anchorWindow = window
		page = "overview"
		opened = true
	}
}
