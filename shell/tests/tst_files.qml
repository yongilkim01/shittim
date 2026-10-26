import QtQuick
import QtQuick.Window
import QtTest
import "../components/files"

TestCase {
    id:testCase;name:"ShittimFiles";width:700;height:500;visible:true;when:windowShown
    Component{id:modelFactory;FilesModel{}}
    Component{id:viewFactory;FilesView{width:440;height:326}}
    Component{id:windowFactory;FilesWindow{visible:false;width:440;height:326}}
    Component{id:spyFactory;SignalSpy{}}
    Component{id:controlFactory;Item{width:96;height:96;FileWindowControl{objectName:"test-control";width:24;height:24}}}
    Component{id:frameFactory;Item{width:720;height:360;FileFrame{objectName:"test-frame";width:240;height:120;maximized:true}}}
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
    function test_resize_keeps_native_ui_metrics_and_frame_at_window_size(){
        const model=setup(),view=createTemporaryObject(viewFactory,testCase,{model:model})
        const design=findChild(view,"files-design"),frame=findChild(view,"files-frame"),button=findChild(view,"files-close"),grid=findChild(view,"files-grid")
        const before={width:button.width,height:button.height,cellWidth:grid.cellWidth,cellHeight:grid.cellHeight}
        for(const size of [[1280,800],[1920,1080],[380,280]]) {
            view.width=size[0];view.height=size[1];view.maximized=true
            compare(design.scale,1);compare(design.width,view.width);compare(design.height,view.height)
            compare(button.width,before.width);compare(button.height,before.height)
            compare(grid.cellWidth,before.cellWidth);compare(grid.cellHeight,before.cellHeight)
            compare(frame.edgeInset,2.5)
        }
        view.maximized=false;compare(frame.edgeInset,2.5)
    }
    function test_maximized_frame_keeps_all_four_edges_visible(){
        const host=createTemporaryObject(frameFactory,testCase),frame=findChild(host,"test-frame")
        waitForRendering(frame)
        const image=grabImage(host),ratio=Screen.devicePixelRatio
        const near=Math.floor(frame.edgeInset*ratio),farX=Math.floor((frame.width-frame.edgeInset)*ratio),farY=Math.floor((frame.height-frame.edgeInset)*ratio)
        const midX=Math.floor(frame.width*ratio/2),midY=Math.floor(frame.height*ratio/2)
        // The inset must fit the full glow, not just the 1px border centerline.
        verify(frame.edgeInset>=2.5)
        for(const point of [[near,midY],[farX,midY],[midX,near],[midX,farY]]) {
            verify(image.red(point[0],point[1])<80 && image.green(point[0],point[1])>80,"프레임 변이 잘리면 안 됨: "+point)
        }
    }
    function test_window_control_paths_have_matching_visible_extent(){
        const host=createTemporaryObject(controlFactory,testCase),control=findChild(host,"test-control")
        let expected=-1
        for(const glyph of ["minimize","maximize","close","restore"]) {
            control.glyph=glyph
            waitForRendering(control)
            // Keep enough capture area for physical pixels at fractional scale factors.
            const image=grabImage(host)
            let left=image.width,right=-1
            for(let y=0;y<image.height;y++)for(let x=0;x<image.width;x++) {
                if(image.red(x,y)<128 && image.green(x,y)>128 && image.blue(x,y)>128){left=Math.min(left,x);right=Math.max(right,x)}
            }
            const extent=right-left+1
            verify(extent>0)
            if(expected<0)expected=extent
            verify(Math.abs(extent-expected)<=1,"동일한 폭이어야 함: "+glyph+" "+extent+" / "+expected)
            verify(Math.abs(extent-16*Screen.devicePixelRatio)<=1,"실제 기호 폭: "+glyph+" "+extent+" / "+(16*Screen.devicePixelRatio))
        }
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
        view.width=380;view.height=280;compare(findChild(view,"files-design").scale,1)
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
