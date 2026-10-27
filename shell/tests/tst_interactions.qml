import QtQuick
import QtTest
import "../core"

TestCase {
    name:"Interactions"
    function init(){failOnWarning(/.*/)}
    Component { id:managerFactory;InteractionModel {} }
    Component { id:sessionFactory;PanelSession { property var callback:null;onRevoked:reason=>{if(callback)callback(reason)} } }
    Component { id:spyFactory;SignalSpy {} }
    function test_single_owner_handoff_and_late_clear_cannot_close_new_panel() {
        const manager=createTemporaryObject(managerFactory,this)
        const first=createTemporaryObject(sessionFactory,this,{coordinator:manager,name:"desktop",kind:"desktop"})
        const second=createTemporaryObject(sessionFactory,this,{coordinator:manager,name:"launcher"})
        const output={},other={}
        verify(first.open(output));verify(first.active);verify(!manager.blockingPopups)
        const revoked=createTemporaryObject(spyFactory,this,{target:first,signalName:"revoked"})
        verify(second.open(other));compare(revoked.count,1);compare(revoked.signalArguments[0][0],"superseded")
        verify(!first.active);verify(second.active);verify(manager.blockingPopups);compare(manager.screen,other)
        first.close("outside");verify(second.active)
        second.close("escape");compare(manager.owner,null)
    }
    function test_reentrant_close_callback_keeps_the_newest_owner() {
        const manager=createTemporaryObject(managerFactory,this),output={}
        const first=createTemporaryObject(sessionFactory,this,{coordinator:manager})
        const next=createTemporaryObject(sessionFactory,this,{coordinator:manager})
        const newest=createTemporaryObject(sessionFactory,this,{coordinator:manager})
        first.callback=function(){newest.open(output)}
        first.open(output);verify(!next.open(output));compare(manager.owner,newest)
    }
    function test_preview_never_overrides_keyboard_policy_and_destroy_releases_owner() {
        const manager=createTemporaryObject(managerFactory,this),output={}
        const session=createTemporaryObject(sessionFactory,this,{coordinator:manager,kind:"preview",keyboard:false})
        session.open(output);verify(!manager.blockingPopups);verify(!session.keyboard)
        session.destroy();wait(0);compare(manager.owner,null)
    }
    function test_anchor_hit_and_explicit_screen_removal() {
        const manager=createTemporaryObject(managerFactory,this),output={},window={}
        const item=Qt.createQmlObject('import QtQuick; Item {width:30;height:20;x:10;y:5}',this)
        const session=createTemporaryObject(sessionFactory,this,{coordinator:manager})
        session.open(output,window,item)
        manager.anchorTapped(window,Qt.point(15,10));verify(session.active)
        manager.anchorTapped(window,Qt.point(90,10));verify(!session.active)
        session.open(output);manager.dismiss("screen-removed");compare(manager.screen,null)
        item.destroy()
    }
}
