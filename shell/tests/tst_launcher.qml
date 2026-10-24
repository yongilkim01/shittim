import QtQuick
import QtTest
import "../components/launcher"
import "../components/launcher/Diagnostics.js" as Diagnostics
import "../components/launcher/IconResolver.js" as Icons

TestCase {
    id: testCase
    name: "AppLauncher"
    width: 500; height: 300; visible: true; when: windowShown
    Component { id: modelFactory; LauncherModel {} }
    Component { id: viewFactory; LauncherView { width: 394; height: 187 } }
    SignalSpy { id: launchSpy; signalName: "launchRequested" }
    SignalSpy { id: closeSpy; signalName: "closeRequested" }
    SignalSpy { id: refreshSpy; signalName: "refreshRequested" }
    function init() { failOnWarning(/.*/) }
    function test_serviceWarningsDoNotBecomeLaunchFailures() {
        verify(!Diagnostics.isFailure("launcher-service.py:19: PyGIDeprecationWarning: Gio.DesktopAppInfo is deprecated; use GioUnix.DesktopAppInfo instead"))
        verify(!Diagnostics.isFailure("  desktop = getattr(Gio, 'DesktopAppInfo', None)"))
        verify(!Diagnostics.isFailure("Gtk-WARNING: optional theme warning"))
        verify(Diagnostics.isFailure("Traceback (most recent call last):"))
        verify(Diagnostics.isFailure("Fatal Python error: initialization failed"))
        verify(Diagnostics.isFailure("GLib-GIO-ERROR: initialization failed"))
    }
    function test_icons_keep_system_theme_and_resolve_missing_file_manager() {
        const bundled = name => "bundled/" + name + ".svg"
        const missing = name => ""
        compare(Icons.resolve({id:"nemo.desktop",icons:["system-file-manager"]},missing,bundled),"bundled/system-file-manager.svg")
        compare(Icons.resolve({id:"other.desktop",icons:["unknown"]},missing,bundled),"bundled/application-x-executable.svg")
        compare(Icons.resolve({icons:["first","second"]},name => name === "second" ? "theme/second" : "",bundled),"theme/second")
        compare(Icons.resolve({iconFile:"file:///tmp/custom.svg"},missing,bundled),"file:///tmp/custom.svg")
    }
    function cleanup() { launchSpy.target = null; closeSpy.target = null; refreshSpy.target = null; launchSpy.clear(); closeSpy.clear(); refreshSpy.clear() }
    function apps() {
        return [{id: "editor.desktop", name: "Code Editor", genericName: "Text editor", keywords: ["개발", "Programming"]},
            {id: "terminal.desktop", name: "Kitty", genericName: "Terminal emulator", keywords: ["Shell"]},
            {id: "korean.desktop", name: "한글 도구 <&>", genericName: "문서", keywords: ["입력"]}]
    }
    function setup(applications) {
        const model = createTemporaryObject(modelFactory, testCase, {applications: applications || apps()})
        const view = createTemporaryObject(viewFactory, testCase, {model: model})
        launchSpy.target = view; closeSpy.target = view; refreshSpy.target = view
        view.focusSearch()
        return {model: model, view: view, input: findChild(view, "launcherSearch"), list: findChild(view, "launcherResults")}
    }
    function test_searchFieldsAndNormalization() {
        const state = setup()
        state.model.query = "  ｋｉｔｔｙ "
        compare(state.model.results.length, 1); compare(state.model.selected.id, "terminal.desktop")
        state.model.query = "text programming"
        compare(state.model.selected.id, "editor.desktop")
        state.model.query = "문서 입력"
        compare(state.model.selected.id, "korean.desktop")
        state.model.query = "does-not-exist"
        compare(state.model.results.length, 0); compare(state.model.selected, null)
    }
    function test_keyboardFocusNavigationLaunchAndEscape() {
        const state = setup()
        tryCompare(state.input, "activeFocus", true)
        keyClick(Qt.Key_Down); compare(state.model.selectedIndex, 1)
        keyClick(Qt.Key_Up); compare(state.model.selectedIndex, 0)
        keyClick(Qt.Key_Return); compare(launchSpy.count, 1)
        compare(launchSpy.signalArguments[0][0], state.model.selected.id)
        keyClick(Qt.Key_Escape); compare(closeSpy.count, 1)
        keyClick(Qt.Key_F5); compare(refreshSpy.count, 1)
    }
    function test_typingFiltersImmediatelyAndResetsSelection() {
        const state = setup()
        keyClick(Qt.Key_Down)
        for (const key of [Qt.Key_K, Qt.Key_I, Qt.Key_T, Qt.Key_T, Qt.Key_Y]) keyClick(key)
        compare(state.model.query, "kitty"); compare(state.model.results.length, 1)
        compare(state.model.selectedIndex, 0)
    }
    function test_emptyAndPendingLaunchAreSafe() {
        const state = setup([])
        keyClick(Qt.Key_Return); compare(launchSpy.count, 0)
        state.model.applications = apps(); state.view.launching = true
        keyClick(Qt.Key_Return); compare(launchSpy.count, 0)
        state.view.launching = false; state.view.ready = false
        keyClick(Qt.Key_Return); compare(launchSpy.count, 0)
    }
    function test_scrollAndMouseLaunchKeepSearchFocus() {
        const entries = []
        for (let i = 0; i < 100; ++i) entries.push({id: "app" + i, name: "App " + String(i).padStart(3, "0"), keywords: []})
        const state = setup(entries)
        for (let i = 0; i < 12; ++i) keyClick(Qt.Key_Down)
        compare(state.model.selectedIndex, 12)
        wait(50)
        verify(state.list.contentY > 0)
        mouseClick(state.list, 80, 12)
        compare(launchSpy.count, 1)
        tryCompare(state.input, "activeFocus", true)
    }
    function test_referenceGeometryAndSmallScreen() {
        const state = setup()
        compare(state.input.x, 43); compare(state.input.height, 31)
        compare(state.list.x, 9); compare(state.list.y, 41)
        compare(state.list.width, 376); compare(state.view.implicitHeight, 187)
        state.view.width = 280; state.view.height = 100
        verify(state.view.contentScale < 1)
        verify(state.list.height > 0)
        state.view.error = "실행 실패 테스트"
        verify(state.list.height > 0)
    }
    function test_catalogueRemovalClampsSelectionAndSupportsLargeLists() {
        const state = setup()
        state.model.move(100); compare(state.model.selectedIndex, 2)
        state.model.applications = [apps()[0]]
        compare(state.model.selectedIndex, 0)
        const entries = []
        for (let i = 0; i < 5000; ++i) entries.push({id: "id" + i, name: "Application " + i, keywords: ["fixture"]})
        state.model.applications = entries; state.model.query = "application 4999"
        compare(state.model.results.length, 1)
        compare(state.model.selected.id, "id4999")
    }
}
