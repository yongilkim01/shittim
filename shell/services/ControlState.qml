pragma Singleton
import QtQuick
import "../core"

QtObject {
	id: root
	readonly property bool opened: session.active
	readonly property var anchorWindow: session.anchorWindow
	readonly property var targetScreen: session.screen
	readonly property alias panelSession: session
	property PanelSession sessionObject: PanelSession {
		id:session
		coordinator:InteractionState;name:"control"
		onRevoked:root.page="overview"
	}
	property string page: "overview"
	function close() { session.close() }
	function show(window, item, destination) {
		session.open(InteractionState.screenFor(window),window,item)
		page=destination || "overview"
	}
	function toggle(window, item) {
		if (opened && anchorWindow === window) { close(); return }
		show(window,item)
	}
}
