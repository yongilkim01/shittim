pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../components/media"
import "../components/media/MediaData.js" as Data

Scope {
    id: root
    property bool opened: false
    property var anchorWindow: null
    property var targetScreen: null
    readonly property alias model: playback
    readonly property var recentWindows: WindowState.recent
    property string error: ""
    property string pendingApp: ""
    property string artworkState: "unloaded"
    readonly property var apps: {
        const favorites = LauncherState.dockFavorites.map(id => LauncherState.model.applications.find(app => app.id === id)).filter(app => app !== undefined)
        return favorites.concat(LauncherState.model.applications.filter(app => LauncherState.dockFavorites.indexOf(app.id) < 0 && Data.matches(app, windows, LauncherState.model.applications, LauncherState.dockWindowClasses).length > 0))
    }
    readonly property var windows: WindowState.windows
    MediaModel { id: playback; players: Mpris.players.values }
    Timer {
        interval: 250; repeat: true
        running: root.opened && playback.playing && playback.player !== null && playback.player.positionSupported
        onTriggered: if (playback.player) playback.player.positionChanged()
    }
    function close() { playback.cancelSeek(); opened = false }
    function show(window) {
        WindowState.close()
        ControlState.close(); NotificationState.close(); LauncherState.close(); DashboardState.close()
        anchorWindow = window || null
        const monitor = Hyprland.focusedMonitor
        targetScreen = window ? window.screen : Quickshell.screens.find(screen => monitor !== null && screen.name === monitor.name) || Quickshell.screens[0] || null
        error = ""
        if (targetScreen !== null) { Hyprland.refreshToplevels(); opened = true }
    }
    function toggle(window) { if (opened) close(); else show(window) }
    function matches(app) { return Data.matches(app, windows, LauncherState.model.applications, LauncherState.dockWindowClasses) }
    function running(app) { return matches(app).length > 0 }
    function activate(app) {
        if (!app || LauncherState.launching) return
        error = ""
        if (!LauncherState.ready || !LauncherState.model.applications.some(candidate => candidate.id === app.id)) {
            error = "앱 목록이 변경되었습니다. F5로 새로고침하세요."
            return
        }
        const candidates = Data.preferred(matches(app), recentWindows)
        const target = candidates[0]
        if (target) {
            close()
            if (!WindowState.perform("activate", target.address)) error = WindowState.error || "창을 활성화할 수 없습니다."
        }
        else { pendingApp = app.id; LauncherState.launch(app.id) }
    }
    Connections {
        target: LauncherState
        function onOpenedChanged() { if (LauncherState.opened) root.close() }
        function onLaunchFinished(appId, ok) {
            if (appId !== root.pendingApp) return
            root.pendingApp = ""
            if (ok) root.close()
            else root.error = LauncherState.error
        }
    }
    Connections { target: ControlState; function onOpenedChanged() { if (ControlState.opened) root.close() } }
    Connections { target: NotificationState; function onOpenedChanged() { if (NotificationState.opened) root.close() } }
    Connections { target: DashboardState; function onOpenedChanged() { if (DashboardState.opened) root.close() } }
    Connections { target: WindowState; function onShowing() { root.close() } }
    Connections { target: Quickshell; function onScreensChanged() { if (root.opened && Quickshell.screens.indexOf(root.targetScreen) < 0) root.close() } }
    IpcHandler {
        target: "media"
        function toggle(): void { root.toggle(null) }
        function show(): void { root.show(null) }
        function hide(): void { root.close() }
        function reload(): void { LauncherState.refresh() }
        function launch(appId: string): string {
            if (!LauncherState.ready || LauncherState.launching) return "busy"
            const app = LauncherState.model.applications.find(candidate => candidate.id === appId)
            if (!app) return "missing"
            ControlState.close(); NotificationState.close(); LauncherState.close(); DashboardState.close()
            root.activate(app)
            return root.error ? "error" : "requested"
        }
        function diagnostics(): string {
            return JSON.stringify({opened: root.opened, artworkState: root.artworkState,
                selected: playback.player ? playback.player.dbusName : "", title: playback.title, artist: playback.artist,
                artAllowed: playback.art.length > 0, playing: playback.playing, position: playback.position, duration: playback.duration,
                players: playback.players.map(player => ({name: player.dbusName, title: Data.text(player.trackTitle), artist: Data.text(player.trackArtist),
                    canControl: player.canControl, canToggle: player.canTogglePlaying, canNext: player.canGoNext,
                    canPrevious: player.canGoPrevious, canSeek: player.canSeek, positionSupported: player.positionSupported,
                    lengthSupported: player.lengthSupported}))})
        }
        function status(): string { return JSON.stringify({opened: root.opened, players: playback.players.length, playing: playback.playing,
            seekable: playback.seekable, favorites: root.apps.length, ready: LauncherState.ready}) }
    }
}
