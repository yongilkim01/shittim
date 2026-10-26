import QtQuick
import QtTest
import "../components/files"

TestCase {
    id:testCase;name:"ShittimFiles";width:700;height:500;visible:true;when:windowShown
    Component{id:modelFactory;FilesModel{}}
    Component{id:viewFactory;FilesView{width:440;height:326}}
    Component{id:windowFactory;FilesWindow{visible:false;width:440;height:326}}
    Component{id:spyFactory;SignalSpy{}}
    function init(){failOnWarning(/.*/)}
    function test_actual_native_window_loads_with_eight_resize_handles(){
        const model=setup(),window=createTemporaryObject(windowFactory,testCase,{browserModel:model})
        verify(window!==null);compare(window.width,440);compare(window.height,326)
        try {
            window.show();tryCompare(window,"visible",true)
            tryVerify(()=>findChild(window.contentItem,"files-resize-"+Qt.LeftEdge)!==null)
            const left=findChild(window.contentItem,"files-resize-"+Qt.LeftEdge),corner=findChild(window.contentItem,"files-resize-"+(Qt.RightEdge|Qt.BottomEdge))
            verify(corner!==null);compare(left.width,5);compare(corner.width,5);compare(corner.height,5)
            const min=createTemporaryObject(spyFactory,testCase,{target:window,signalName:"minimizeRequested"})
            findChild(window.contentItem,"files-minimize").clicked();compare(min.count,1)
        } finally { window.destroy();wait(0) }
    }
    function test_managed_maximize_uses_controller_signal_and_real_state_for_restore_icon(){
        const model=setup(),window=createTemporaryObject(windowFactory,testCase,{browserModel:model,managedMaximize:true,maximized:false})
        try {
            const max=createTemporaryObject(spyFactory,testCase,{target:window,signalName:"maximizeRequested"})
            const button=findChild(window.contentItem,"files-maximize")
            const edge=findChild(window.contentItem,"files-resize-"+Qt.LeftEdge)
            compare(button.glyph,"maximize");verify(edge.enabled)
            button.clicked();compare(max.count,1);compare(window.maximized,false)
            window.maximized=true;compare(button.glyph,"restore");verify(!edge.enabled)
            button.clicked();compare(max.count,2);compare(window.maximized,true)
            window.maximized=false;compare(button.glyph,"maximize");verify(edge.enabled)
        } finally { window.destroy();wait(0) }
    }
    function listing(model,uri,entries){return {event:"listing",request:model.current.request,tab:model.current.id,uri:uri,name:"Home",parent:"file:///",writable:true,entries:entries || [],breadcrumbs:[],truncated:false}}
    function setup(){
        const model=createTemporaryObject(modelFactory,testCase)
        model.accept({event:"ready",home:"file:///home/test",places:[{name:"Home",uri:"file:///home/test",icon:"home",group:"places"}]})
        model.open(model.homeUri,false)
        model.accept(listing(model,model.homeUri,[{id:"folder",uri:"file:///home/test/한글",name:"한글 폴더",directory:true,hidden:false,size:0,icons:[]},{id:"file",uri:"file:///home/test/a.txt",name:"<b>file</b>.txt",directory:false,hidden:false,size:4,icons:[]}]))
        return model
    }
    function test_tabs_ignore_outdated_reads_and_keep_history_and_closed_operations(){
        const model=setup(),old=listing(model,"file:///old")
        model.navigate("file:///new");model.accept(old);compare(model.current.uri,model.homeUri)
        model.accept(listing(model,"file:///new"));compare(model.current.history.length,2)
        model.history(-1);model.accept(listing(model,model.homeUri));compare(model.current.position,0)
        model.open("file:///second",true);compare(model.tabs.length,2)
        model.accept(listing(model,"file:///second"))
        model.action("folder",{name:"test"});const request=model.operationRequest,tab=model.current.id
        model.closeTab(1);model.accept({event:"done",tab:tab,request:request});compare(model.operationRequest,-1)
    }
    function test_reference_view_selection_window_controls_and_address_navigation(){
        const model=setup(),view=createTemporaryObject(viewFactory,testCase,{model:model})
        const selected=findChild(view,"files-entry-0");verify(selected!==null)
        mouseClick(selected,20,20);compare(model.selected.length,1)
        mouseClick(findChild(view,"files-entry-1"),20,20,Qt.LeftButton,Qt.ControlModifier);compare(model.selected.length,2)
        mouseClick(findChild(view,"files-entry-1"),20,20,Qt.LeftButton,Qt.ControlModifier);compare(model.selected.length,1)
        const min=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"minimizeRequested"})
        const max=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"maximizeRequested"})
        const close=createTemporaryObject(spyFactory,testCase,{target:view,signalName:"closeRequested"})
        mouseClick(findChild(view,"files-minimize"),12,10);compare(min.count,1)
        mouseClick(findChild(view,"files-maximize"),12,10);compare(max.count,1)
        mouseClick(findChild(view,"files-close"),12,10);compare(close.count,1)
        view.forceActiveFocus();keyClick(Qt.Key_L,Qt.ControlModifier)
        const address=findChild(view,"files-address");verify(address.visible);address.text="file:///한글 폴더";keyClick(Qt.Key_Return)
        verify(model.current.pending);compare(findChild(view,"files-grid").cellWidth,55)
        view.width=380;view.height=280;verify(view.contentScale>0)
    }
    function test_monitor_refresh_keeps_filter_selection_and_reports_errors_without_retry_loop(){
        const model=setup();model.selected=["folder"];model.query="한글"
        model.refresh();verify(model.busy);compare(model.query,"한글");compare(model.selected.length,1)
        model.accept(listing(model,model.homeUri,[{id:"folder",uri:"file:///home/test/한글",name:"한글 폴더",directory:true,hidden:false}]))
        compare(model.selected.length,1)
        model.navigate("file:///missing");model.accept({event:"error",tab:model.current.id,request:model.current.request,error:"NotFound"})
        verify(!model.busy);verify(!model.current.dirty);verify(model.error.length>0)
    }
}
