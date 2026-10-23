import QtQuick
import QtTest
import "../components/notifications"
import "../components/notifications/NotificationData.js" as Data
import "../ui"

TestCase {
    id: testCase
    name: "Notifications"
    width: 600; height: 500; visible: true; when: windowShown
    Component { id: modelFactory; NotificationModel {} }
    Component { id: viewFactory; NotificationView { width: 360; height: 187 } }
    Component { id: rowFactory; NotificationRow { width: 358; height: implicitHeight } }
    Component { id: bindingFactory; NotificationBinding { resolveIcon: name => "" } }
    QtObject {
        id: notificationFixture
        property int id: 42
        property string summary: "native"
        property string body: "body"
        property string appName: "fixture"
        property string desktopEntry: "fixture.desktop"
        property string appIcon: ""
        property string image: ""
        property int urgency: 1
        property int expireTimeout: 6000
        property bool lastGeneration: false
        property var hints: ({})
        property var actions: []
        signal closed(int reason)
    }
    function init() { failOnWarning(/.*/); notificationFixture.summary = "native"; notificationFixture.lastGeneration = false }
    function fixtureData(id, changes) {
        return Object.assign({id: id, summary: "Test notification", body: "한글 <b>본문</b> & text", appName: "Test fixture",
            desktopEntry: "test.desktop", icon: "", image: "", category: "app", urgency: 1, transient: false, timeout: -1, restored: false, actions: []}, changes || {})
    }
    function makeModel() { return createTemporaryObject(modelFactory, testCase) }
    function test_replaceCloseAndUnread() {
        const model = makeModel()
        model.receive(fixtureData(1), 1000); model.receive(fixtureData(1, {summary: "updated"}), 2000)
        compare(model.history.length, 1); compare(model.unread, 1); compare(model.get(1).created, 1000)
        compare(model.get(1).received, 2000); compare(model.get(1).summary, "updated")
        model.closed(1, 1); compare(model.history.length, 1); compare(model.popups.length, 0); compare(model.get(1).live, false)
        model.closed(1, 3); compare(model.history.length, 0)
    }
    function test_dndCriticalAndNoReplay() {
        const model = makeModel(); model.dnd = true
        model.receive(fixtureData(1)); model.receive(fixtureData(2, {urgency: 2}))
        compare(model.history.length, 2); compare(model.popups.length, 1); compare(model.popups[0].id, 2)
        model.dnd = false; compare(model.popups.length, 1)
        model.receive(fixtureData(3)); compare(model.popups.length, 2)
        model.dnd = true; compare(model.popups.length, 1)
    }
    function test_openMarksReadAndNewWhileOpen() {
        const model = makeModel(); model.receive(fixtureData(1)); model.viewed = true
        compare(model.unread, 0); compare(model.popups.length, 0)
        model.receive(fixtureData(2)); compare(model.unread, 0); compare(model.popups.length, 0)
        model.viewed = false; model.receive(fixtureData(3)); compare(model.unread, 1)
    }
    function test_timeoutUnitsAndCriticalPolicy() {
        const model = makeModel()
        model.receive(fixtureData(1), 1000); compare(model.get(1).deadline, 7000)
        model.receive(fixtureData(2, {timeout: 1250}), 1000); compare(model.nextDeadline, 2250)
        model.receive(fixtureData(3, {timeout: 0}), 1000); compare(model.get(3).deadline, 0)
        model.receive(fixtureData(4, {urgency: 2}), 1000); compare(model.get(4).deadline, 0)
        const spy = createTemporaryObject(spyFactory, testCase, {target: model, signalName: "expireRequested"})
        model.expireDue(2249); compare(spy.count, 0)
        model.expireDue(2250); compare(spy.count, 1); compare(spy.signalArguments[0][0], 2)
        model.closed(2, 1); verify(model.get(2) !== null); compare(model.get(2).actions.length, 0)
    }
    Component { id: spyFactory; SignalSpy {} }
    function test_boundedHistoryTransientAndPopupDismiss() {
        const model = makeModel(); model.limit = 4
        const spy = createTemporaryObject(spyFactory, testCase, {target: model, signalName: "dismissRequested"})
        for (let i = 0; i < 8; ++i) model.receive(fixtureData(i))
        compare(model.entries.length, 4); compare(model.popups.length, 3); compare(spy.count, 4)
        model.dismissPopup(7); model.closed(7, 2); compare(model.history.length, 4); compare(model.get(7).live, false)
        model.receive(fixtureData(8, {transient: true})); verify(!model.history.some(entry => entry.id === 8))
        model.closed(8, 1); compare(model.get(8), null)
        model.clear(); compare(model.entries.length, 0); compare(model.unread, 0)
    }
    function test_safeMetadata() {
        compare(Data.category({category: "device.added"}), "system")
        compare(Data.category({category: "network.connected"}), "system")
        compare(Data.category({category: "im.received"}), "app")
        compare(Data.category({}), "app")
        compare(Data.iconName("../../secrets.png"), ""); compare(Data.iconName("https://test"), "")
        compare(Data.image("file:///etc/passwd"), ""); compare(Data.image("https://test/image.png"), "")
        compare(Data.image("image://qsimage/12/1"), "image://qsimage/12/1")
        compare(Data.text("a\u0000\u202eb", 10), "ab")
        compare(Data.text("x".repeat(9000), 8192).length, 8192)
        compare(Data.relative(1000, 121000), "2m ago")
    }
    function test_nativeReplacementBindings() {
        const model = makeModel()
        model.receive(Data.snapshot(notificationFixture, name => ""))
        const watcher = createTemporaryObject(bindingFactory, testCase, {notification: notificationFixture, model: model})
        wait(10); compare(model.history.length, 1)
        notificationFixture.summary = "replaced <script>"
        tryCompare(model, "unread", 1)
        tryVerify(() => model.get(42).summary === "replaced <script>")
        compare(model.history.length, 1)
        notificationFixture.closed(3); compare(model.history.length, 0)
        notificationFixture.summary = "already closed"; wait(10); compare(model.history.length, 0)
    }
    function test_restoredNoPopupUntilReplacement() {
        const model = makeModel(); notificationFixture.lastGeneration = true
        model.receive(Data.snapshot(notificationFixture, name => "")); compare(model.unread, 0); compare(model.popups.length, 0)
        const watcher = createTemporaryObject(bindingFactory, testCase, {notification: notificationFixture, model: model})
        notificationFixture.summary = "new replacement"
        tryCompare(model, "unread", 1); compare(model.popups.length, 1)
    }
    function test_memoryReloadPreservesTimeUnreadAndNoNativeReferences() {
        const original = makeModel(); original.receive(fixtureData(1), 1000)
        const saved = JSON.parse(JSON.stringify(original.entries))
        const model = makeModel(); model.restore(saved)
        compare(model.get(1).live, false); compare(model.unread, 1); compare(model.popups.length, 0)
        model.receive(fixtureData(1, {restored: true}), 3000)
        compare(model.get(1).received, 1000); compare(model.get(1).deadline, 7000); compare(model.unread, 1); compare(model.popups.length, 0)
        model.closed(1, 1)
        const next = makeModel(); next.restore(JSON.parse(JSON.stringify(model.entries)))
        compare(next.history.length, 1); compare(next.get(1).actions.length, 0); compare(next.get(1).image, "")
    }
    function test_reloadKeepsExpiredAndLiveHistoryInArrivalOrder() {
        const original = makeModel()
        original.receive(fixtureData(1, {timeout: 0}), 1000)
        original.receive(fixtureData(2), 2000); original.closed(2, 1)
        const model = makeModel(); model.restore(JSON.parse(JSON.stringify(original.entries)))
        model.receive(fixtureData(1, {restored: true, timeout: 0}), 5000)
        compare(model.history[0].id, 2); compare(model.history[1].id, 1)
        model.receive(fixtureData(1, {summary: "new update", timeout: 0}), 6000)
        compare(model.history[0].id, 1); compare(model.history[0].received, 6000)
    }
    function test_referenceLayoutTabsAndEmpty() {
        const model = makeModel(); model.receive(fixtureData(1, {category: "system"})); model.receive(fixtureData(2))
        const view = createTemporaryObject(viewFactory, testCase, {model: model})
        const list = findChild(view, "notificationList")
        compare(list.x, 1); compare(list.y, 44); compare(list.width, 358)
        compare(view.results.length, 2)
        mouseClick(view, 86, 18); compare(view.tab, "system"); compare(view.results.length, 1)
        mouseClick(view, 154, 18); compare(view.tab, "app"); compare(view.results.length, 1)
        mouseClick(view, 309, 18); compare(model.history.length, 0)
        view.ownership = "conflict"; wait(10)
    }
    function test_detailsPlainTextActionsAndSmallScreen() {
        const model = makeModel(); model.receive(fixtureData(1, {body: "긴 본문 ".repeat(100), actions: [{id: "open", text: "열기"}]}))
        const row = createTemporaryObject(rowFactory, testCase, {entry: model.get(1)})
        const collapsed = row.height; row.expanded = true; verify(row.height > collapsed)
        const view = createTemporaryObject(viewFactory, testCase, {model: model, width: 280, height: 100})
        verify(view.contentScale < 1)
        view.expandedId = 1
        const list = findChild(view, "notificationList"); wait(20); verify(list.contentHeight > list.height)
        const spy = createTemporaryObject(spyFactory, testCase, {target: view, signalName: "closeRequested"})
        view.forceActiveFocus(); keyClick(Qt.Key_Escape); compare(spy.count, 1)
    }
    function test_mouseDetailsActionsAndDeletion() {
        const model = makeModel(); model.receive(fixtureData(1, {actions: [{id: "open", text: "열기"}]}))
        const view = createTemporaryObject(viewFactory, testCase, {model: model})
        const row = findChild(view, "notification-row-1")
        mouseClick(row, 90, 18)
        compare(view.expandedId, 1); compare(model.unread, 0)
        const action = findChild(view, "notification-action-open")
        verify(action !== null)
        const spy = createTemporaryObject(spyFactory, testCase, {target: view, signalName: "actionRequested"})
        mouseClick(action, action.width / 2, action.height / 2)
        compare(spy.count, 1); compare(spy.signalArguments[0][0], 1); compare(spy.signalArguments[0][1], "open")
        const current = findChild(view, "notification-row-1")
        current.forceActiveFocus(); mouseMove(current, current.width - 20, 15)
        mouseClick(current, current.width - 20, 15)
        compare(model.history.length, 0)
    }
    function test_timeAndCloseNeverOverlap_data() {
        return [{tag: "popup", popup: true, width: 360}, {tag: "center", popup: false, width: 358},
            {tag: "narrow-popup", popup: true, width: 280}]
    }
    function test_timeAndCloseNeverOverlap(data) {
        const model = makeModel(); model.receive(fixtureData(1, {summary: "긴 알림 제목 ".repeat(20)}))
        const row = createTemporaryObject(rowFactory, testCase, {entry: model.get(1), popup: data.popup, width: data.width})
        const time = findChild(row, "notificationTime")
        const close = findChild(row, "notificationClose")
        const summary = findChild(row, "notificationSummary")
        mouseMove(row, 90, 15)
        compare(time.visible, true); compare(close.visible, true)
        verify(summary.x + summary.width < time.x)
        verify(time.x + time.width < close.x)
        mouseMove(close, close.width / 2, close.height / 2)
        compare(time.visible, true); compare(close.visible, true)
        verify(time.x + time.width < close.x)
    }
    function test_hoverStaysInsideNotification_data() {
        return [{tag: "popup", popup: true, width: 360, expanded: false},
            {tag: "narrow-popup", popup: true, width: 280, expanded: false},
            {tag: "details", popup: false, width: 358, expanded: true}]
    }
    function test_hoverStaysInsideNotification(data) {
        const model = makeModel(); model.receive(fixtureData(1, {body: "긴 본문 ".repeat(100)}))
        const row = createTemporaryObject(rowFactory, testCase, {entry: model.get(1), popup: data.popup, width: data.width, expanded: data.expanded})
        const hover = findChild(row, "notificationHover")
        mouseMove(row, 90, 15)
        verify(hover.opacity > 0); compare(row.clip, true)
        verify(hover.x > 0 && hover.y > 0)
        verify(hover.x + hover.width < row.width)
        verify(hover.y + hover.height < row.height)
        const close = findChild(row, "notificationClose")
        mouseMove(close, close.width / 2, close.height / 2)
        verify(hover.opacity > 0)
    }
}
