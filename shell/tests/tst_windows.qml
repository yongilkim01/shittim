import QtQuick
import QtTest
import "../components/windows"

TestCase {
    id: testCase
    name: "WindowManagement"; width: 800; height: 480; visible: true; when: windowShown
    Component { id: modelFactory; WindowModel {} }
    Component { id: viewFactory; WindowView { width: 680; height: 420 } }
    Component { id: spyFactory; SignalSpy {} }
    function init() { failOnWarning(/.*/) }
    function entries() { return [{address:"abc",title:"한글 <b>title</b>",className:"Nemo",workspace:"1",hidden:false,floating:true,fullscreen:0},
        {address:"def",title:"Chrome",className:"chrome",workspace:"special:shittim-hidden-2-0-0-def",hidden:true,floating:true,fullscreen:0}] }
    function test_keyboardSelectionFilteringAndClosedWindow() {
        const m=createTemporaryObject(modelFactory,testCase,{windows:entries(),recent:["abc","def"]})
        m.start(1); compare(m.selectedAddress,"def")
        m.step(1); compare(m.selectedAddress,"abc")
        m.step(-1); compare(m.selectedAddress,"def")
        m.windows=[entries()[0]]; compare(m.selectedAddress,"abc")
        m.allowedAddresses=["missing"]; compare(m.selected,null)
        m.windows=[]; m.start(1); m.step(1); compare(m.selectedAddress,"")
    }
    function test_windowViewActionsAndSmallViewport() {
        const m=createTemporaryObject(modelFactory,testCase,{windows:entries()})
        const view=createTemporaryObject(viewFactory,testCase,{model:m})
        const spy=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        view.forceActiveFocus(); keyClick(Qt.Key_Down); compare(m.selectedAddress,"def")
        keyClick(Qt.Key_Return); compare(spy.count,1); compare(spy.signalArguments[0][0],"activate"); compare(spy.signalArguments[0][1],"def")
        view.width=320; view.height=200
        compare(findChild(view,"windowList").width,296)
        compare(findChild(view,"windowList").height,114)
    }
    function test_altReleaseCommitsOnlyWhenCycling() {
        const view=createTemporaryObject(viewFactory,testCase)
        const spy=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"commitRequested"})
        view.forceActiveFocus(); keyClick(Qt.Key_Alt); compare(spy.count,0)
        view.cycling=true; keyClick(Qt.Key_Alt); compare(spy.count,1)
    }
    function test_mouseHideRestoreAndPlainTextTitle() {
        const m=createTemporaryObject(modelFactory,testCase,{windows:entries()})
        const view=createTemporaryObject(viewFactory,testCase,{model:m})
        const spy=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        mouseClick(findChild(view,"window-hide-abc"),15,14)
        compare(spy.signalArguments[0][0],"hide"); compare(spy.signalArguments[0][1],"abc")
        mouseClick(findChild(view,"window-hide-def"),15,14)
        compare(spy.signalArguments[1][0],"activate"); compare(spy.signalArguments[1][1],"def")
        compare(findChild(view,"window-maximize-def").enabled,false)
        compare(findChild(view,"window-title-abc").textFormat,Text.PlainText)
        compare(findChild(view,"window-title-abc").text,"한글 <b>title</b>")
    }
}
