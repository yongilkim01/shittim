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
        compare(strip.height,52); compare(strip.width,92)
        compare(view.errorItem.height,0)
        const image=findChild(view,"dock-image-nemo.desktop")
        compare(image.width,30); compare(image.height,30)
        view.app=app; view.mode="preview"
        compare(strip.y,originalY); compare(strip.height,52)
        verify(view.popupItem.y+view.popupItem.height<=strip.y)
        view.mode="menu"
        compare(strip.y,originalY)
        view.mode=""; view.error="Fixture error"
        compare(strip.y,originalY); compare(view.errorItem.height,42)
        view.error=""; compare(view.errorItem.height,0)
    }
}
