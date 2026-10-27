import QtQuick
import QtTest
import "../components/desktop"
import "../components/dock"

TestCase {
    id:testCase
    name:"DesktopUX"; width:1000; height:650; visible:true; when:windowShown
    Component { id:modelFactory; DesktopModel {} }
    Component { id:desktopFactory; DesktopView { width:800; height:500 } }
    Component { id:dockFactory; DockView { width:720; height:420 } }
    Component { id:spyFactory; SignalSpy {} }
    function init() { failOnWarning(/.*/) }
    function entries() { return [{id:"home",name:"Home",uri:"file:///home/test",directory:true,special:true,icons:[]},
        {id:"file:///home/test/Desktop/한글.txt",name:"한글.txt",uri:"file:///home/test/Desktop/한글.txt",directory:false,special:false,icons:[]}] }
    function test_selection_move_restore_clamp_and_file_disappearance() {
        const model=createTemporaryObject(modelFactory,testCase,{entries:entries(),areaWidth:800,areaHeight:500})
        const spy=createTemporaryObject(spyFactory,testCase,{target:model,signalName:"positionsChangedByUser"})
        model.select("home",false); model.select(entries()[1].id,true); compare(model.selected.length,2)
        model.move(200,40); compare(spy.count,1); compare(model.saved.home[0],200)
        model.areaWidth=100; model.areaHeight=100
        compare(model.position(entries()[0],0)[0],12); compare(model.position(entries()[0],0)[1],8)
        model.entries=[entries()[0]]; compare(model.selected.length,1)
        model.selected=[]; model.selectRect(0,0,100,100,false); compare(model.selected[0],"home")
    }
    function test_desktop_single_select_double_open_keyboard_and_clear() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const spy=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        const home=findChild(view,"desktop-icon-home")
        mouseClick(home,30,30); compare(view.model.selected[0],"home"); compare(spy.count,0)
        mouseDoubleClickSequence(home,30,30); tryCompare(spy,"count",1); compare(spy.signalArguments[0][0],"open")
        view.forceActiveFocus(); keyClick(Qt.Key_C,Qt.ControlModifier); compare(spy.signalArguments[1][0],"copy")
        mouseClick(view,750,450); compare(view.model.selected.length,0)
    }
    function test_dock_left_right_multi_window_hidden_and_small_layout() {
        const app={id:"test.desktop",name:"Test",icons:[]}
        const clients=[{address:"abc",title:"Window <b>one</b>",hidden:true,activated:false}]
        const view=createTemporaryObject(dockFactory,testCase,{apps:[app],favorites:[app.id],matches:function(){return clients}})
        const click=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"appClicked"})
        const menu=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"appMenu"})
        const cell=findChild(view,"dock-app-test.desktop")
        mouseClick(cell,20,20); compare(click.count,1)
        mouseClick(cell,20,20,Qt.RightButton); compare(menu.count,1); compare(click.count,1)
        compare(findChild(view,"dock-image-test.desktop").opacity,0.4)
        view.mode="menu"; view.app=app; view.windows=clients; view.target=clients[0]
        compare(findChild(view,"dock-action-hide").enabled,false)
        compare(findChild(view,"dock-action-activate").enabled,true)
        view.mode="choose"
        const chosen=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"windowChosen"})
        mouseClick(findChild(view,"dock-preview-abc"),60,50); compare(chosen.signalArguments[0][0],"abc")
        view.width=300; verify(view.stripItem.width<=300); verify(view.popupItem.width<=300)
    }
    function test_compact_dock_strip_stays_fixed_during_preview_menu_and_errors() {
        const app={id:"nemo.desktop",name:"Files",icons:[]}
        const view=createTemporaryObject(dockFactory,testCase,{apps:[app],favorites:[app.id]})
        const strip=view.stripItem, originalY=strip.y
        compare(strip.height,64); compare(strip.width,254)
        compare(view.errorItem.height,0)
        const image=findChild(view,"dock-image-nemo.desktop")
        compare(image.width,32); compare(image.height,32)
        view.app=app; view.mode="preview"
        compare(strip.y,originalY); compare(strip.height,64)
        verify(view.popupItem.y+view.popupItem.height<=strip.y)
        view.mode="menu"
        compare(strip.y,originalY)
        view.mode=""; view.error="Fixture error"
        compare(strip.y,originalY); compare(view.errorItem.height,42)
        view.error=""; compare(view.errorItem.height,0)
    }
    function test_reference_utilities_open_settings_trash_and_keep_launcher_access() {
        const view=createTemporaryObject(dockFactory,testCase)
        const settings=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"settingsRequested"})
        const launcher=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"launcherRequested"})
        const trash=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"trashRequested"})
        mouseClick(findChild(view,"dock-settings"),15,15); compare(settings.count,1)
        mouseClick(findChild(view,"dock-settings"),15,15,Qt.RightButton); compare(launcher.count,1)
        mouseClick(findChild(view,"dock-launcher"),15,15);compare(launcher.count,2)
        mouseClick(findChild(view,"dock-trash"),15,15); compare(trash.count,1)
        view.trashAvailable=false
        mouseClick(findChild(view,"dock-trash"),15,15); compare(trash.count,1)
    }
    function test_desktop_focus_is_explicit_and_released_without_losing_selection() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const focus=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"focusRequested"})
        const requested=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        mouseClick(view,750,450);compare(focus.count,1);verify(view.activeFocus)
        view.releaseFocus();verify(!view.activeFocus)
        mouseClick(findChild(view,"desktop-icon-home"),30,30);compare(focus.count,2)
        compare(view.model.selected[0],"home")
        view.releaseFocus();verify(!view.activeFocus);compare(view.model.selected[0],"home")
        keyClick(Qt.Key_C,Qt.ControlModifier);compare(requested.count,0)
        view.takeFocus();compare(focus.count,3)
        keyClick(Qt.Key_C,Qt.ControlModifier);compare(requested.count,1)
        compare(requested.signalArguments[0][0],"copy")
    }
    function test_returning_input_closes_desktop_popups_without_applying_file_changes() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const requested=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        mouseClick(view,750,450,Qt.RightButton)
        const menu=findChild(view,"desktop-context-menu"),prompt=findChild(view,"desktop-name-prompt")
        tryCompare(menu,"visible",true)
        view.releaseFocus();tryCompare(menu,"visible",false);verify(!view.activeFocus)
        view.takeFocus();view.model.selected=[entries()[1].id];view.request("rename")
        tryCompare(prompt,"visible",true)
        view.releaseFocus();tryCompare(prompt,"visible",false);verify(!view.activeFocus)
        compare(requested.count,0)
    }
    function test_recorded_grab_clear_then_queued_press_does_not_reacquire_focus() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const focus=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"focusRequested"})
        const ignored=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"focusRejected"})
        mouseClick(view,750,450);compare(focus.count,1)
        // Laptop log at 3410/3411ms: cleared -> delayed desktop press -> keyboard leave.
        for(let cycle=0;cycle<3;cycle++) {
            view.releaseFocus(true);verify(!view.activeFocus)
            mousePress(view,650,300)
            compare(focus.count,cycle+1);compare(ignored.count,cycle+1);verify(!view.activeFocus)
            mouseRelease(view,650,300);verify(!view.inputHandoff)
            mouseClick(view,750,450);compare(focus.count,cycle+2);verify(view.activeFocus)
        }
    }
    function test_replayed_icon_gesture_cannot_select_open_drag_or_show_a_menu() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const focus=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"focusRequested"})
        const requested=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"requested"})
        const positions=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"positionsSaved"})
        mouseClick(view,750,450)
        const home=findChild(view,"desktop-icon-home")
        view.model.selected=[entries()[1].id]
        view.releaseFocus(true)
        mousePress(home,30,30);mouseMove(home,65,55)
        compare(focus.count,1);compare(view.model.selected[0],entries()[1].id)
        mouseRelease(home,65,55);compare(positions.count,0);compare(requested.count,0)
        view.releaseFocus(true)
        mouseClick(home,30,30,Qt.RightButton)
        verify(!findChild(view,"desktop-context-menu").visible);compare(focus.count,1)
        // A later genuine gesture still selects and opens the same icon.
        mouseDoubleClickSequence(home,30,30);tryCompare(requested,"count",1)
        compare(requested.signalArguments[0][0],"open")
    }
    function test_handoff_during_an_existing_press_invalidates_its_click() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        mousePress(view,750,450,Qt.RightButton)
        view.releaseFocus(true)
        mouseRelease(view,750,450,Qt.RightButton)
        verify(!findChild(view,"desktop-context-menu").visible)
        verify(!view.activeFocus);verify(!view.inputHandoff)
        mouseClick(view,750,450,Qt.RightButton)
        tryCompare(findChild(view,"desktop-context-menu"),"visible",true)
    }
    function test_no_replayed_press_rearms_on_a_new_pointer_visit() {
        const view=createTemporaryObject(desktopFactory,testCase,{entries:entries()})
        const focus=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"focusRequested"})
        mouseClick(view,750,450);view.releaseFocus(true)
        // Some outside-click routes send the press straight to the other application.
        mouseMove(testCase,950,600);tryCompare(view,"handoffExited",true)
        mouseMove(view,650,300);tryCompare(view,"inputHandoff",false)
        mouseClick(view,650,300);compare(focus.count,2);verify(view.activeFocus)
    }
}
