pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "../components/media"
import "../components/media/MediaData.js" as Data
import "../core"

Scope {
    id: root
    readonly property bool opened:session.active
    readonly property var anchorWindow:session.anchorWindow
    readonly property var targetScreen:session.screen
    readonly property alias panelSession:session
    PanelSession { id:session;coordinator:InteractionState;name:"media";onRevoked:playback.cancelSeek() }
    readonly property alias model: playback
    property string artworkState: "unloaded"
    MediaModel { id: playback; players: Mpris.players.values }
    Timer {
        interval: 250; repeat: true
        running: root.opened && playback.playing && playback.player !== null && playback.player.positionSupported
        onTriggered: if (playback.player) playback.player.positionChanged()
    }
    function close() { session.close();playback.cancelSeek() }
    function show(window, item) {
        session.open(InteractionState.screenFor(window),window,item)
    }
    function toggle(window, item) { if (opened) close(); else show(window,item) }
    IpcHandler {
        target: "media"
        function toggle(): void { root.toggle(null) }
        function show(): void { root.show(null) }
        function hide(): void { root.close() }
        function reload(): void { ApplicationCatalog.refresh() }
        function launch(appId: string): string {
            if (!ApplicationCatalog.ready || ApplicationCatalog.launching) return "busy"
            const app = ApplicationCatalog.applications.find(candidate => candidate.id === appId)
            if (!app) return "missing"
            return ApplicationsState.activate(app) ? "requested" : "error"
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
            seekable: playback.seekable, favorites: ApplicationsState.apps.length, ready: ApplicationCatalog.ready}) }
    }
}
