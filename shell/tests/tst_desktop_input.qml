import QtQuick
import QtTest
import "../components/desktop"

TestCase {
    name:"DesktopInputTrace"
    Component { id:factory;DesktopInputTrace {} }
    function test_disabled_trace_does_not_collect_or_change_input() {
        const trace=createTemporaryObject(factory,this)
        trace.requested=true;trace.windowActive=true;trace.record("desktop-press")
        compare(trace.events.length,0);verify(trace.requested);verify(trace.windowActive)
    }
    function test_keyboard_focus_is_distinct_from_requested_and_item_focus() {
        const trace=createTemporaryObject(factory,this,{enabled:true})
        trace.record("desktop-press");trace.requested=true;trace.grabbed=true
        trace.windowActive=true;trace.viewFocused=true
        trace.record("grab-cleared");trace.grabbed=false;trace.requested=false;trace.windowActive=false
        const state=trace.snapshot()
        verify(!state.windowActive);verify(!state.requested);verify(state.viewFocused)
        verify(state.events.some(event=>event.event==="keyboard" && event.windowActive))
        verify(state.events.some(event=>event.event==="grab-cleared"))
    }
    function test_trace_is_bounded_and_new_capture_discards_previous_events() {
        const trace=createTemporaryObject(factory,this,{enabled:true})
        for(let index=0;index<100;index++)trace.record("desktop-press")
        compare(trace.events.length,64)
        trace.enabled=false;trace.record("grab-cleared");compare(trace.events.length,64)
        trace.enabled=true;compare(trace.events.length,1);compare(trace.events[0].event,"start")
    }
    function test_attached_window_active_reports_actual_qt_window() {
        const item=Qt.createQmlObject('import QtQuick; Item { readonly property bool keyboardActive: Window.active }',this)
        compare(typeof item.keyboardActive,"boolean");item.destroy()
    }
}
