import QtQuick
import QtTest
import "../components/dashboard"
import "../components/dashboard/Format.js" as Format

TestCase {
    id: testCase
    name: "SystemDashboard"
    width: 800; height: 400; visible: true; when: windowShown
    Component { id: modelFactory; DashboardModel {} }
    Component { id: viewFactory; DashboardView { width: 746; height: 300 } }
    Component { id: detailFactory; Item { objectName: "fixtureDetail" } }
    Component { id: spyFactory; SignalSpy {} }
    function init() { failOnWarning(/.*/) }
    function sample(time, iface) {
        return {event: "sample", time: time, cpu: {name: "Test CPU", percent: 12}, memory: {used: 12 * 1024 ** 3, total: 32 * 1024 ** 3, percent: 37.5},
            gpu: {name: "Test GPU", percent: null}, temperature: {value: 42, label: "Test sensor", critical: 100},
            storage: [{mount: "/", device: "/dev/test disk", filesystem: "ext4", used: 128 * 1024 ** 3, total: 1024 ** 4, percent: 12.5}], storageReady: true,
            network: {interface: iface, down: 12800, up: 1024, interfaces: []}}
    }
    function makeModel() { return createTemporaryObject(modelFactory, testCase) }
    function test_missingHardwareAndReferenceGeometry() {
        const model = makeModel()
        const view = createTemporaryObject(viewFactory, testCase, {model: model})
        for (const title of ["CPU", "RAM", "GPU", "TEMP"]) {
            const gauge = findChild(view, "dashboardGauge-" + title)
            verify(gauge !== null); compare(gauge.display, "N/A")
            compare(gauge.value, -1)
        }
        const storage = findChild(view, "dashboardStorage"), network = findChild(view, "dashboardNetwork")
        compare(storage.x, 140); compare(storage.y, 169); compare(storage.width, 326)
        compare(network.x, 480); compare(network.y, 169); compare(network.width, 249)
        compare(findChild(view, "dashboardMenu-System"), null)
        compare(findChild(view, "dashboardMenu-system").y, 18)
        compare(findChild(view, "dashboardMenu-settings").y, 249)
    }
    function test_actualValuesAndHistoryBoundedByInterface() {
        const model = makeModel(); model.receive(sample(1000, "test0"))
        const view = createTemporaryObject(viewFactory, testCase, {model: model})
        compare(findChild(view, "dashboardGauge-CPU").display, "12%")
        compare(findChild(view, "dashboardGauge-GPU").display, "N/A")
        compare(findChild(view, "dashboardGauge-TEMP").display, "42°C")
        const graph = findChild(view, "dashboardNetworkGraph")
        tryCompare(graph, "available", true)
        for (let i = 1; i < 100; ++i) model.receive(sample(1000 + i * 1000, "test0"))
        compare(model.samples.length, 60)
        graph.requestPaint(); wait(30)
        model.receive(sample(102000, "test1")); compare(model.samples.length, 1)
        model.failure("test failure"); compare(model.ready, false); compare(model.snapshot.cpu.percent, null)
        compare(model.samples.length, 0); compare(model.error, "test failure")
        model.reset(); compare(model.samples.length, 0); compare(model.ready, false)
    }
    function test_sidebarEveryMenuAndEscape() {
        const view = createTemporaryObject(viewFactory, testCase, {model: makeModel(), detailComponent: detailFactory})
        const spy = createTemporaryObject(spyFactory, testCase, {target: view, signalName: "navigate"})
        for (const key of ["system", "apps", "bluetooth", "display", "network", "audio", "power", "settings"]) {
            const menu = findChild(view, "dashboardMenu-" + key)
            mouseClick(menu, 65, 15)
            compare(spy.signalArguments[spy.count - 1][0], key)
            view.page = key
            compare(menu.active, true)
        }
        verify(findChild(view, "fixtureDetail") !== null)
        const close = createTemporaryObject(spyFactory, testCase, {target: view, signalName: "closeRequested"})
        view.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(close.count, 1)
    }
    function test_smallScreenKeepsFourGaugesAndTwoColumns() {
        const model = makeModel(); model.receive(sample(1000, "test0"))
        const view = createTemporaryObject(viewFactory, testCase, {model: model, width: 520, height: 300 * 520 / 746})
        compare(view.contentScale, 1)
        const viewport=findChild(view,"dashboardViewport")
        verify(viewport.contentWidth>viewport.width)
        viewport.contentX=viewport.contentWidth-viewport.width
        verify(viewport.contentX>0)
        const cpu = findChild(view, "dashboardGauge-CPU"), temp = findChild(view, "dashboardGauge-TEMP")
        verify(temp.x > cpu.x); compare(cpu.y, temp.y)
        compare(findChild(view, "dashboardStorage").y, findChild(view, "dashboardNetwork").y)
    }
    function test_formatUnknownIsNotZero() {
        compare(Format.percent(null), "N/A"); compare(Format.percent(0), "0%")
        compare(Format.rate(null), "N/A"); compare(Format.rate(0), "0 B/s")
        compare(Format.bytes(1024), "1.0 KiB"); compare(Format.fraction(null), -1)
    }
}
