import QtQuick
import QtTest
import "../components/media"
import "../components/media/MediaData.js" as Data

TestCase {
    id: testCase
    name: "AppMediaControls"
    width: 600; height: 400; visible: true; when: windowShown
    Component { id: modelFactory; MediaModel {} }
    Component { id: viewFactory; MediaView { width: 349; height: 271 } }
    Component { id: spyFactory; SignalSpy {} }
    Component {
        id: playerFactory
        QtObject {
            property string dbusName: "org.mpris.MediaPlayer2.fixture"
            property string identity: "Fixture player"
            property string trackTitle: "테스트 <b>title</b>"
            property string trackArtist: "Artist"
            property string trackArtUrl: ""
            property bool isPlaying: true
            property bool canControl: true
            property bool canTogglePlaying: true
            property bool canGoPrevious: true
            property bool canGoNext: true
            property bool canSeek: true
            property bool positionSupported: true
            property bool lengthSupported: true
            property real length: 232
            property real position: 134
            property int uniqueId: 1
            property int previousCalls: 0
            property int nextCalls: 0
            function togglePlaying() { isPlaying = !isPlaying }
            function previous() { previousCalls++ }
            function next() { nextCalls++ }
        }
    }
    function init() { failOnWarning(/.*/) }
    function model(players) { return createTemporaryObject(modelFactory, testCase, {players: players || []}) }
    function player(values) { return createTemporaryObject(playerFactory, testCase, values || {}) }
    function test_emptyAndReferenceGeometry() {
        const m = model(), v = createTemporaryObject(viewFactory, testCase, {model: m, ready: true})
        compare(m.title, "NO ACTIVE MEDIA"); compare(m.duration, -1); compare(m.position, -1)
        compare(findChild(v, "mediaArtwork").x, 24); compare(findChild(v, "mediaArtwork").width, 88)
        compare(findChild(v, "mediaPlayerFrame").height, 163)
        compare(findChild(v, "mediaDockFrame").y, 199); compare(findChild(v, "mediaDockFrame").height, 72)
        compare(findChild(v, "mediaToggle").enabled, false)
        compare(findChild(v, "mediaSeek").enabled, false)
    }
    function test_liveMetadataActionsAndCapabilityGates() {
        const p = player(), m = model([p]), v = createTemporaryObject(viewFactory, testCase, {model: m})
        compare(findChild(v, "mediaTitle").text, "테스트 <b>title</b>")
        compare(findChild(v, "mediaTitle").textFormat, Text.PlainText)
        mouseClick(findChild(v, "mediaToggle"), 15, 14); compare(p.isPlaying, false)
        mouseClick(findChild(v, "mediaPrevious"), 15, 14); compare(p.previousCalls, 1)
        mouseClick(findChild(v, "mediaNext"), 15, 14); compare(p.nextCalls, 1)
        p.canGoNext = false; compare(findChild(v, "mediaNext").enabled, false)
        m.next(); compare(p.nextCalls, 1)
        p.canControl = false; compare(m.canToggle, false); compare(m.seekable, false)
        p.trackTitle = "Updated"; compare(findChild(v, "mediaTitle").text, "Updated")
    }
    function test_autoPlayingSelectionManualSwitchAndExit() {
        const paused = player({dbusName: "paused", isPlaying: false}), playing = player({dbusName: "playing"})
        const m = model([paused, playing]); compare(m.player, playing)
        m.cyclePlayer(); compare(m.player, paused)
        paused.isPlaying = true; compare(m.player, paused)
        m.players = [playing]; compare(m.selectedName, ""); compare(m.player, playing)
        m.players = []; compare(m.player, null)
        m.players = [paused, playing]; paused.isPlaying = false; compare(m.player, playing)
        playing.isPlaying = false; compare(m.player, paused)
    }
    function test_seekClampedUnsupportedAndTrackRace() {
        const p = player(), m = model([p])
        m.beginSeek(); m.finishSeek(2); compare(p.position, 232)
        m.beginSeek(); m.finishSeek(-1); compare(p.position, 0)
        m.beginSeek(); p.uniqueId++; m.finishSeek(0.5); compare(p.position, 0)
        m.beginSeek(); m.finishSeek(NaN); compare(p.position, 0)
        m.beginSeek(); m.cancelSeek(); m.finishSeek(0.5); compare(p.position, 0)
        m.beginSeek(); p.canSeek = false; m.finishSeek(0.5); compare(p.position, 0)
        p.canSeek = true; p.lengthSupported = false; compare(m.duration, -1); compare(m.seekable, false)
        p.positionSupported = false; compare(m.position, -1)
        p.trackTitle = ""; p.trackArtist = ""; p.isPlaying = false
        compare(m.title, "NO ACTIVE MEDIA"); compare(m.art, "")
    }
    function test_sliderDragCommitsOnReleaseOnly() {
        const p = player(), m = model([p]), v = createTemporaryObject(viewFactory, testCase, {model: m})
        const slider = findChild(v, "mediaSeek")
        mousePress(slider, 10, 8); mouseMove(slider, 100, 8)
        compare(p.position, 134)
        mouseRelease(slider, 100, 8); verify(p.position > 100 && p.position < 150)
        p.isPlaying = false; p.position = 10
        tryVerify(() => Math.abs(slider.value - 10 / 232) < 0.001)
    }
    function test_artworkUriAndPlainTextBounds() {
        for (const uri of ["data:image/svg+xml,anything", "qrc:/etc/passwd", "file://remote/image", "https://u:p@host/image", "https://host/space image", "javascript:alert(1)"])
            compare(Data.artwork(uri), "")
        for (const uri of ["file:///tmp/album%20art.png", "file://localhost/tmp/album.png", "https://example.test/image.png", "http://localhost:8080/image"])
            compare(Data.artwork(uri), uri)
        compare(Data.text("x\n\u0000y"), "x  y"); compare(Data.text("x".repeat(5000)).length, 2048)
        compare(Data.time(-1), "--:--"); compare(Data.time(134), "02:14"); compare(Data.time(3601), "1:00:01")
    }
    function test_playerRestartWithSameBusNameCannotReceiveOldSeek() {
        const original = player(), replacement = player(), m = model([original])
        m.beginSeek(); m.players = [replacement]; m.finishSeek(0.9)
        compare(replacement.position, 134)
    }
    function test_exactWindowMappingAndAmbiguity() {
        const app = {id: "editor.desktop", startupWMClass: "Editor"}, other = {id: "other.desktop", startupWMClass: "Other"}
        const windows = [{address: "1", appId: "editor"}, {address: "2", className: "Editor"}, {address: "3", className: "Editor-beta"}]
        compare(Data.matches(app, windows, [app, other], {}).length, 2)
        other.startupWMClass = "Editor"; compare(Data.matches(app, windows, [app, other], {}).length, 1)
        compare(Data.matches(app, windows, [app, other], {"editor.desktop": ["Editor-beta"]})[0].address, "3")
        compare(Data.matches(app, [{className: "editor-title"}], [app], {}).length, 0)
    }
    function test_dockAndSmallScreenAndKeyboard() {
        const app = {id: "fixture.desktop", name: "실제 앱 <&>"}
        const v = createTemporaryObject(viewFactory, testCase, {model: model(), apps: [app], ready: true,
            width: 280, height: 271 * 280 / 349, isRunning: function(a) { return a.id === app.id }, isActiveApp: function(a) { return a.id === app.id }})
        const button = findChild(v, "dock-fixture.desktop")
        verify(button !== null); compare(button.running, true); compare(button.tooltipText, app.name)
        compare(v.contentScale, 280 / 349)
        const launch = createTemporaryObject(spyFactory, testCase, {target: v, signalName: "appRequested"})
        mouseClick(button, 21, 21); compare(launch.count, 1); compare(launch.signalArguments[0][0].id, app.id)
        compare(button.active, true)
        const context = createTemporaryObject(spyFactory, testCase, {target: v, signalName: "appWindowsRequested"})
        mouseClick(button, 21, 21, Qt.RightButton); compare(context.count, 1); compare(launch.count, 1)
        compare(context.signalArguments[0][0].id, app.id)
        v.launching = true; compare(button.enabled, false)
        const close = createTemporaryObject(spyFactory, testCase, {target: v, signalName: "closeRequested"})
        v.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(close.count, 1)
    }
    function test_multipleWindowsPreferActiveThenRecentThenStableAddress() {
        const windows = [{address: "b", activated: false}, {address: "a", activated: false}, {address: "c", activated: true}]
        compare(Data.preferred(windows, ["b"])[0].address, "c")
        windows[2].activated = false
        compare(Data.preferred(windows, ["b"])[0].address, "b")
        compare(Data.preferred(windows, [])[0].address, "a")
        compare(windows[0].address, "b")
    }
}
