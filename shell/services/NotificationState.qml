pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../components/notifications"
import "../components/notifications/NotificationData.js" as Data

Scope {
    id: root
    readonly property alias model: history
    property bool opened: false
    property var anchorWindow: null
    property var targetScreen: null
    property int detailId: -1
    property var popupScreen: null
    property string ownership: "checking"
    property int ownerPid: 0
    readonly property bool available: ownership === "owned"
    readonly property bool dnd: history.dnd
    readonly property int unread: history.unread
    property bool restored: false
    function live(id) { return server.trackedNotifications.values.find(notification => notification.id === id) || null }
    function toggleDnd() { history.dnd = !history.dnd }
    function close() { opened = false }
    function toggle(window) {
        if (opened && anchorWindow === window) { close(); return }
        ControlState.close(); LauncherState.close()
        anchorWindow = window
        if (anchorWindow === null) return
        targetScreen = window.screen
        detailId = -1
        opened = true
    }
    function showDetail(id) {
        const screen = popupScreen || focusedScreen()
        ControlState.close(); LauncherState.close()
        anchorWindow = null; targetScreen = screen; detailId = id
        opened = screen !== null
    }
    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor
        return Quickshell.screens.find(screen => monitor !== null && screen.name === monitor.name) || Quickshell.screens[0] || null
    }
    function iconSource(name) { return name ? Quickshell.iconPath(name, true) : "" }
    function invoke(id, actionId) {
        const notification = live(id)
        if (notification === null) return
        const action = notification.actions.find(candidate => candidate.identifier === actionId)
        if (action) { history.replace(id, {read: true, popup: false}); action.invoke() }
    }
    PersistentProperties {
        id: memory
        reloadableId: "shittim-notification-memory"
        property string entries: "[]"
        property bool dnd: false
        onLoaded: {
            try { history.restore(JSON.parse(entries)) } catch (_) { history.restore([]) }
            history.dnd = dnd
            root.restored = true
        }
    }
    NotificationModel {
        id: history
        viewed: root.opened
        onExpireRequested: id => { const notification = root.live(id); if (notification) notification.expire() }
        onDismissRequested: id => { const notification = root.live(id); if (notification) notification.dismiss() }
        onEntriesChanged: {
            if (popups.length > 0 && root.popupScreen === null) root.popupScreen = root.focusedScreen()
            if (popups.length === 0) root.popupScreen = null
            scheduler.reschedule()
            if (root.restored) memory.entries = JSON.stringify(entries)
        }
        onDndChanged: if (root.restored) memory.dnd = dnd
    }
    NotificationServer {
        id: server
        keepOnReload: true; persistenceSupported: true; bodySupported: true
        actionsSupported: true; imageSupported: true
        bodyMarkupSupported: false; bodyHyperlinksSupported: false; bodyImagesSupported: false
        actionIconsSupported: false; inlineReplySupported: false
        onNotification: notification => {
            notification.tracked = true
            history.receive(Data.snapshot(notification, root.iconSource))
        }
    }
    Instantiator {
        model: server.trackedNotifications
        delegate: NotificationBinding {
            required property var modelData
            notification: modelData; model: history; resolveIcon: root.iconSource
        }
    }
    Timer {
        id: scheduler
        function reschedule() {
            stop()
            if (Number.isFinite(history.nextDeadline)) {
                interval = Math.max(1, Math.min(2147483647, history.nextDeadline - Date.now()))
                start()
            }
        }
        onTriggered: { history.expireDue(Date.now()); reschedule() }
    }
    Connections { target: ControlState; function onOpenedChanged() { if (ControlState.opened) root.close() } }
    Connections { target: LauncherState; function onOpenedChanged() { if (LauncherState.opened) root.close() } }
    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (root.opened && Quickshell.screens.indexOf(root.targetScreen) < 0) root.close()
            if (root.popupScreen !== null && Quickshell.screens.indexOf(root.popupScreen) < 0) root.popupScreen = root.focusedScreen()
        }
    }
    Process {
        command: ["python3", "-u", Quickshell.shellDir + "/../scripts/notification-owner.py", "--watch"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                try { const result = JSON.parse(data); root.ownership = result.state; root.ownerPid = result.pid || 0 }
                catch (_) { root.ownership = "error" }
            }
        }
        stderr: SplitParser { onRead: data => { root.ownership = "error" } }
        onExited: root.ownership = "error"
    }
    IpcHandler {
        target: "notifications"
        function status(): string { return JSON.stringify({ownership: root.ownership, pid: root.ownerPid, count: history.history.length, unread: history.unread, dnd: history.dnd, opened: root.opened}) }
        function dndOn(): void { history.dnd = true }
        function dndOff(): void { history.dnd = false }
        function clear(): void { history.clear() }
        function hide(): void { root.close() }
        function contains(id: int): bool { return history.get(id) !== null }
    }
}
