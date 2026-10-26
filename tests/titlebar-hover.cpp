// Run the actual hover publisher against a deterministic compositor/IPC test fixture.
#include "../native/titlebars/controls.hpp"
#include "../native/titlebars/interaction.hpp"
#include <cassert>
#include <cstdint>
#include <format>
#include <memory>
#include <string>
#include <vector>

struct Vector2D { double x, y; };
struct Box { double x, y, w, h; };
template<class T> struct Value { T data; T value() const { return data; } T valueOrDefault() const { return data; } };
template<class T> struct Ref {
    std::shared_ptr<T> ptr;
    auto lock() const { return ptr; }
    T* operator->() const { return ptr.get(); }
};
struct Monitor { int m_id=0;Vector2D m_position{1920,0}; };
struct Rules { bool decorated=true;Value<bool> decorate() { return {decorated}; } };
struct Window { Rules* m_ruleApplicator;Ref<Monitor> m_monitor;bool maximized=false,mapped=true; };
bool validMapped(const Ref<Window>& window) { return window.lock() && window->mapped; }
struct Button { std::string icon;double size=24; };
struct State {
    Value<bool> enabled{true};Value<int> height{24},padding{10},edge{12};Value<std::string> alignment{"right"};
    struct { Value<bool>* enabled;Value<int>* barHeight;Value<int>* barButtonPadding;Value<int>* barPadding;Value<std::string>* barButtonsAlignment; } config{&enabled,&height,&padding,&edge,&alignment};
    std::vector<Button> buttons{{"×"},{"□"},{"−"}};
} state;
auto* g_pGlobalState=&state;
struct Event { std::string event,data; };
struct Events { std::vector<Event> values;void postEvent(Event event){values.push_back(event);} } events;
auto* g_pEventManager=&events;
std::shared_ptr<Window> underCursor;
class CHyprBar {
public:
    Ref<Window> m_pWindow;bool m_hidden=false;std::string m_shittimHoverPayload;int m_shittimHoverIndex=-1,damage=0;
    Vector2D cursor{416,12};double assignedWidth=440,assignedHeight=24;
    void damageEntire(){++damage;}
    bool inputIsValid(){
#include "../native/titlebars/input-gate.cpp.inc"
        return true;
    }
    Box assignedBoxGlobal(){return {2000,40,assignedWidth,assignedHeight};}
    Vector2D cursorRelativeToBar(){return cursor;}
    size_t getVisibleButtonCount(int,int,Vector2D,double){return state.buttons.size();}
    void updateShittimHover();void clearShittimHover();
};
#define __SHITTIM_MAXIMIZED__ m_pWindow->maximized
#define __SHITTIM_UNDER_CURSOR__ m_pWindow.lock()==underCursor
#include "../native/titlebars/hover.cpp.inc"

int main(){
    Rules rules;
    auto window=std::make_shared<Window>();window->m_ruleApplicator=&rules;window->m_monitor.ptr=std::make_shared<Monitor>();
    CHyprBar bar;bar.m_pWindow.ptr=window;underCursor=window;
    // Recorded Files geometry: its own maximize slot overlaps the hidden native close slot.
    const double cursorX=821,windowX=422,windowWidth=436;
    const ShittimHUD::HoverRect nativeClose{windowWidth-10-24-12,0,34,24};
    const ShittimHUD::HoverRect nativeMaximize{windowWidth-10-24-12-34,0,34,24};
    assert(ShittimHUD::contains(nativeClose,cursorX-windowX,175-153));
    assert(ShittimHUD::contains(nativeMaximize,807-windowX,174-153));
    assert(bar.inputIsValid());
    const auto press=[&](double x){
        if(!bar.inputIsValid())return "client";
        if(ShittimHUD::contains(nativeClose,x-windowX,175-153))return "close";
        return ShittimHUD::contains(nativeMaximize,x-windowX,175-153) ? "maximize" : "title";
    };
    assert(std::string(press(821))=="close");assert(std::string(press(807))=="maximize");
    rules.decorated=false;assert(!bar.inputIsValid());assert(std::string(press(821))=="client");assert(std::string(press(807))=="client");
    bar.assignedHeight=0;assert(!bar.inputIsValid());assert(std::string(press(821))=="client");
    rules.decorated=true;assert(!bar.inputIsValid());
    bar.assignedHeight=24;bar.assignedWidth=0;assert(!bar.inputIsValid());
    bar.assignedWidth=440;bar.m_hidden=true;assert(!bar.inputIsValid());
    bar.m_hidden=false;state.enabled.data=false;assert(!bar.inputIsValid());
    state.enabled.data=true;state.height.data=0;assert(!bar.inputIsValid());
    state.height.data=24;assert(bar.inputIsValid());
    bar.updateShittimHover();assert(bar.m_shittimHoverIndex==0);
    assert(events.values.back().data.find(",close,0,484,40,24,24")!=std::string::npos);
    const auto count=events.values.size();bar.updateShittimHover();assert(events.values.size()==count);
    bar.cursor={382,12};bar.updateShittimHover();assert(bar.m_shittimHoverIndex==1);
    assert(events.values.back().data.find(",maximize,")!=std::string::npos);
    window->maximized=true;bar.updateShittimHover();assert(events.values.back().data.find(",restore,")!=std::string::npos);
    underCursor=std::make_shared<Window>();bar.updateShittimHover();assert(bar.m_shittimHoverIndex==-1);
    assert(events.values.back().data.ends_with(",leave"));
    underCursor=window;bar.updateShittimHover();const auto damage=bar.damage;
    bar.m_pWindow.ptr.reset();bar.updateShittimHover();assert(bar.damage==damage);
    assert(!bar.inputIsValid());
    assert(bar.m_shittimHoverPayload.empty() && events.values.back().data.ends_with(",leave"));
}
