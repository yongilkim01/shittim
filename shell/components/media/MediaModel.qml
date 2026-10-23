import QtQuick
import "MediaData.js" as Data

QtObject {
    id: root
    property var players: []
    property string selectedName: ""
    readonly property var player: players.find(candidate => candidate.dbusName === selectedName)
        || players.find(candidate => candidate.isPlaying) || players[0] || null
    readonly property bool hasMedia: player !== null && (playing || duration > 0 || Data.text(player.trackTitle).length > 0 || Data.text(player.trackArtist).length > 0)
    readonly property string title: hasMedia ? Data.text(player.trackTitle) || Data.text(player.identity) || "UNKNOWN TITLE" : "NO ACTIVE MEDIA"
    readonly property string artist: hasMedia ? Data.text(player.trackArtist) : ""
    readonly property string art: hasMedia ? Data.artwork(player.trackArtUrl) : ""
    readonly property bool playing: player !== null && player.isPlaying
    readonly property real duration: player && player.lengthSupported && Number.isFinite(player.length) && player.length > 0 ? player.length : -1
    readonly property real position: player && player.positionSupported && Number.isFinite(player.position) ? Math.max(0, player.position) : -1
    readonly property bool seekable: player !== null && player.canControl && player.canSeek && player.positionSupported && duration > 0
    readonly property bool canToggle: player !== null && player.canControl && player.canTogglePlaying
    readonly property bool canPrevious: player !== null && player.canControl && player.canGoPrevious
    readonly property bool canNext: player !== null && player.canControl && player.canGoNext
    property var seekOwner: null
    property var seekTrack: null
    onPlayersChanged: if (selectedName && !players.some(candidate => candidate.dbusName === selectedName)) selectedName = ""
    function cyclePlayer() {
        if (players.length < 2) return
        selectedName = players[(players.indexOf(player) + 1) % players.length].dbusName
    }
    function toggle() { if (canToggle) player.togglePlaying() }
    function previous() { if (canPrevious) player.previous() }
    function next() { if (canNext) player.next() }
    function beginSeek() { seekOwner = player; seekTrack = player ? player.uniqueId : null }
    function cancelSeek() { seekOwner = null; seekTrack = null }
    function finishSeek(fraction) {
        if (seekable && player === seekOwner && player.uniqueId === seekTrack && Number.isFinite(fraction))
            player.position = Math.min(1, Math.max(0, fraction)) * duration
        cancelSeek()
    }
}
