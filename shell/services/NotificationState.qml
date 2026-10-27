pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../components/notifications"
import "../components/notifications/NotificationData.js" as Data
import "../core"

Scope {
    id: root
    readonly property alias model: history
    readonly property bool opened: session.active
    readonly property var anchorWindow: session.anchorWindow
    readonly property var targetScreen: session.screen
    readonly property alias panelSession: session
    PanelSession { id:session;coordinator:InteractionState;name:"notifications" }
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
    function close() { session.close() }
    function toggle(window, item) {
        if (opened && anchorWindow === window) { close(); return }
        if (window === null) return
        detailId = -1
        session.open(InteractionState.screenFor(window),window,item)
    }
    function showDetail(id) {
        const screen = popupScreen || focusedScreen()
        detailId = id
        session.open(screen)
    }
    function focusedScreen() {
        return InteractionState.screenFor(null)
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
    Connections {
        target: Quickshell
        function onScreensChanged() {
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
        function show(): void { root.detailId=-1;session.open(root.focusedScreen()) }
        function contains(id: int): bool { return history.get(id) !== null }
    }
}
