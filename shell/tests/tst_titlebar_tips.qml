import QtQuick
import QtTest
import "../components/windows"

TestCase {
    id:testCase
    name:"TitlebarTips"
    Component { id:factory;TitlebarTipModel{} }
    function init(){failOnWarning(/.*/)}
    function test_delayed_hint_labels_owner_and_exit_order(){
        const model=createTemporaryObject(factory,testCase)
        verify(model.accept("abc,maximize,0,100,40,24,24"));compare(model.label,"최대화");verify(!model.opened)
        model.reveal();verify(model.opened)
        verify(model.accept("def,close,1,300,100,24,24"));compare(model.label,"닫기");verify(!model.opened)
        model.accept("abc,leave");compare(model.owner,"def")
        model.reveal();verify(model.opened)
        verify(model.accept("def,restore,1,300,100,24,24"));compare(model.label,"복원");verify(!model.opened)
        model.accept("def,leave");verify(!model.active);verify(!model.opened)
    }
    function test_invalid_events_do_not_replace_current_hover(){
        const model=createTemporaryObject(factory,testCase)
        model.accept("abc,minimize,0,0,40,24,24")
        for(const payload of ["<b>,close,0,0,0,24,24","abc,unknown,0,0,0,24,24","abc,close,0,NaN,0,24,24","abc,close,0,0,0,-24,24","abc,close,0,,0,24,24"]){verify(!model.accept(payload));compare(model.action,"minimize")}
        compare(model.label,"최소화")
    }
    function test_tooltip_is_clamped_to_selected_monitor(){
        const model=createTemporaryObject(factory,testCase)
        model.accept("abc,close,2,1900,1060,24,24")
        const position=model.position(1920,1080,100,24)
        compare(position.x,1820);verify(position.y>=0 && position.y+24<=1080)
        model.accept("abc,close,2,-100,-100,24,24")
        const negative=model.position(800,600,100,24);compare(negative.x,0);compare(negative.y,0)
    }
}
