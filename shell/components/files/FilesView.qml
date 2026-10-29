import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"

FocusScope {
    id: root
    required property var model
    property var iconSource: function(entry) { return "" }
    property bool maximized: false
    property bool windowControlBusy: false
    property bool editingAddress: false
    property bool searching: false
    signal minimizeRequested()
    signal maximizeRequested()
    signal closeRequested()
    signal dragRequested()
    readonly property var sidebarRows: {
        const rows=[]; let group="places"
        for(const place of model.places) {
            if(place.group!==group) { group=place.group; rows.push({heading:true,name:group}) }
            rows.push(Object.assign({heading:false},place))
        }
        return rows
    }
    function showDialog(action) {
        form.action=action; formInput.text=action==="rename" ? (model.current.entries.find(entry=>entry.id===model.selected[0]) || {}).name || "" : ""
        form.open(); formInput.forceActiveFocus(); formInput.selectAll()
    }
    function activateSelected() { const entry=model.entries.find(candidate=>candidate.id===model.selected[0]); if(entry)model.activate(entry) }
    function searchFolder() { searching=!searching;editingAddress=false;if(searching)search.forceActiveFocus();else{search.text="";model.query="";forceActiveFocus()} }
    Connections { target:root.model;function onQueryChanged(){if(!root.model.query)search.text=""} }
    Keys.onPressed: event => {
        const ctrl=Boolean(event.modifiers & Qt.ControlModifier), alt=Boolean(event.modifiers & Qt.AltModifier)
        if(ctrl && event.key===Qt.Key_L) { root.editingAddress=true; address.text=model.current ? model.current.uri : ""; address.forceActiveFocus(); address.selectAll() }
        else if(ctrl && event.key===Qt.Key_F) searchFolder()
        else if(ctrl && event.key===Qt.Key_T) model.open(model.homeUri,true)
        else if(ctrl && event.key===Qt.Key_W) model.closeTab(model.activeIndex)
        else if(ctrl && event.key===Qt.Key_A) model.selected=model.entries.map(entry=>entry.id)
        else if(ctrl && event.key===Qt.Key_C) model.action("copy")
        else if(ctrl && event.key===Qt.Key_X) model.action("cut")
        else if(ctrl && event.key===Qt.Key_V) model.action("paste")
        else if(ctrl && event.key===Qt.Key_H) model.showHidden=!model.showHidden
        else if(ctrl && (event.modifiers & Qt.ShiftModifier) && event.key===Qt.Key_N) showDialog("folder")
        else if(alt && event.key===Qt.Key_Left) model.history(-1)
        else if(alt && event.key===Qt.Key_Right) model.history(1)
        else if(alt && event.key===Qt.Key_Up) model.up()
        else if(event.key===Qt.Key_F5) model.refresh()
        else if(event.key===Qt.Key_F2 && model.selected.length===1) showDialog("rename")
        else if(event.key===Qt.Key_Delete && !model.inTrash) model.action("trash")
        else if(event.key===Qt.Key_Return || event.key===Qt.Key_Enter) activateSelected()
        else if(event.key===Qt.Key_Left) model.moveSelection(-1)
        else if(event.key===Qt.Key_Right) model.moveSelection(1)
        else if(event.key===Qt.Key_Up) model.moveSelection(model.viewMode==="list" ? -1 : -Math.max(1,Math.floor(grid.width/grid.cellWidth)))
        else if(event.key===Qt.Key_Down) model.moveSelection(model.viewMode==="list" ? 1 : Math.max(1,Math.floor(grid.width/grid.cellWidth)))
        else { event.accepted=false; return }
        event.accepted=true
    }
    Item {
        id: design; objectName:"files-design"; width:root.width; height:root.height
        FileFrame { anchors.fill:parent; maximized:root.maximized }
        MouseArea { x:5;y:4;width:parent.width-10;height:30; onPressed:root.dragRequested(); onDoubleClicked:root.maximizeRequested() }
        Flickable {
            x:10;y:11;width:Math.max(80,parent.width-114);height:25;contentWidth:tabs.width;clip:true;boundsBehavior:Flickable.StopAtBounds
            Row {
                id:tabs;spacing:3
                Repeater {
                    model:root.model.tabs
                    delegate: Item {
                        required property var modelData;required property int index
                        width:110;height:25
                        Rectangle { anchors.fill:parent;radius:2;color:index===root.model.activeIndex ? Theme.fileSurface : Theme.transparent;border.color:index===root.model.activeIndex ? Theme.fileTabBorder : Theme.transparent }
                        FileGlyph { x:7;y:6;width:12;height:12;glyph:modelData.uri===root.model.homeUri ? "home" : "folder";ink:Theme.accentBright }
                        HudText { x:25;y:3;width:57;height:19;font.pixelSize:Theme.fileCaption;text:modelData.name;color:index===root.model.activeIndex ? Theme.textPrimary : Theme.textSecondary }
                        MouseArea {
                            anchors.fill:parent;property real startX:0;property real startY:0;property bool moving:false
                            onPressed:mouse=>{startX=mouse.x;startY=mouse.y;moving=false;root.model.selectTab(index);root.forceActiveFocus()}
                            onPositionChanged:mouse=>{if(pressed && !moving && Math.abs(mouse.x-startX)+Math.abs(mouse.y-startY)>8){moving=true;root.dragRequested()}}
                        }
                        FileButton { x:84;y:0;width:Theme.minimumTarget;height:Theme.minimumTarget;glyph:"close";ink:Theme.accentDim;hint:"탭 닫기";onClicked:root.model.closeTab(index) }
                    }
                }
            }
        }
        Row {
            anchors.right:parent.right;anchors.rightMargin:7;y:8;spacing:2
            FileButton { objectName:"files-minimize";windowControl:true;glyph:"minimize";hint:"최소화";enabled:!root.windowControlBusy;onClicked:root.minimizeRequested() }
            FileButton { objectName:"files-maximize";windowControl:true;glyph:root.maximized ? "restore" : "maximize";hint:root.maximized ? "복원" : "최대화";enabled:!root.windowControlBusy;onClicked:root.maximizeRequested() }
            FileButton { objectName:"files-close";windowControl:true;glyph:"close";hint:"닫기";onClicked:root.closeRequested() }
        }
        Rectangle { x:4;y:36;width:parent.width-8;height:1;color:Theme.fileBorder }
        FileButton { x:8;y:39;glyph:"back";hint:"뒤로";enabled:root.model.current!==null && root.model.current.position>0;onClicked:root.model.history(-1) }
        FileButton { x:34;y:39;glyph:"forward";hint:"앞으로";enabled:root.model.current!==null && root.model.current.position<root.model.current.history.length-1;onClicked:root.model.history(1) }
        FileButton { x:61;y:39;glyph:"home";hint:"홈";onClicked:root.model.navigate(root.model.homeUri) }
        HudText { x:90;y:39;width:parent.width-208;height:22;font.pixelSize:Theme.fileCaption;text:root.model.current ? root.model.current.name : "";color:Theme.textPrimary
            MouseArea { anchors.fill:parent;onClicked:{root.editingAddress=true;address.text=root.model.current ? root.model.current.uri : "";address.forceActiveFocus();address.selectAll()} }
        }
        Rectangle { x:90;y:39;width:parent.width-208;height:22;color:Theme.fileSurface;border.color:Theme.border;visible:root.editingAddress
            TextInput { id:address;objectName:"files-address";anchors.fill:parent;anchors.margins:4;clip:true;font.family:Theme.fontMono;font.pixelSize:Theme.fileCaption;color:Theme.textPrimary;selectByMouse:true
                onAccepted:{root.model.navigate(text);root.editingAddress=false;root.forceActiveFocus()}
                Keys.onEscapePressed:{root.editingAddress=false;root.forceActiveFocus()}
            }
        }
        Rectangle { x:90;y:39;width:parent.width-208;height:22;color:Theme.fileSurface;border.color:Theme.border;visible:root.searching
            TextInput { id:search;objectName:"files-search";anchors.fill:parent;anchors.margins:4;clip:true;font.family:Theme.fontMono;font.pixelSize:Theme.fileCaption;color:Theme.textPrimary;selectByMouse:true
                onTextEdited:root.model.query=text
                Keys.onEscapePressed:{text="";root.model.query="";root.searching=false;root.forceActiveFocus()}
            }
        }
        FileButton { x:parent.width-119;y:39;glyph:"search";hint:"현재 폴더 검색";active:root.searching;onClicked:root.searchFolder() }
        FileButton { x:parent.width-92;y:39;glyph:"list";hint:"목록 보기";active:root.model.viewMode==="list";onClicked:root.model.viewMode="list" }
        FileButton { x:parent.width-66;y:39;glyph:"grid";hint:"아이콘 보기";active:root.model.viewMode==="icons";onClicked:root.model.viewMode="icons" }
        FileButton { x:parent.width-30;y:39;glyph:"menu";hint:"파일 작업";onClicked:{context.x=design.width-context.width-8;context.y=63;context.open()} }
        Rectangle { x:4;y:63;width:parent.width-8;height:1;color:Theme.fileBorder }
        Rectangle { x:4;y:64;width:90;height:parent.height-72;color:Theme.fileSidebar }
        Rectangle { x:96;y:64;width:1;height:parent.height-70;color:Theme.fileBorder }
        Flickable {
            x:7;y:69;width:87;height:parent.height-77;contentHeight:placesColumn.height;clip:true;boundsBehavior:Flickable.StopAtBounds
            Column {
                id:placesColumn;width:parent.width;spacing:0
                Repeater {
                    model:root.sidebarRows
                    delegate: Item {
                        required property var modelData
                        width:87;height:modelData.heading ? 23 : 19
                        readonly property bool chosen: !modelData.heading && root.model.current!==null && root.model.current.uri===modelData.uri
                        Rectangle { anchors.fill:parent;anchors.margins:1;radius:2;color:chosen ? Theme.fileActive : sideMouse.containsMouse ? Theme.surface : Theme.transparent;border.color:chosen ? Theme.accentDim : Theme.transparent }
                        FileGlyph { visible:!modelData.heading;x:5;y:4;width:11;height:11;glyph:modelData.icon || "folder";ink:chosen ? Theme.accentBright : Theme.textSecondary }
                        HudText { x:modelData.heading ? 4 : 22;y:modelData.heading ? 5 : 1;width:parent.width-x-2;height:17;font.pixelSize:Theme.fileCaption;text:modelData.name;color:modelData.heading || chosen ? Theme.accent : Theme.textPrimary }
                        MouseArea { id:sideMouse;anchors.fill:parent;enabled:!modelData.heading;hoverEnabled:true;onClicked:{root.model.navigate(modelData.uri);root.forceActiveFocus()} }
                    }
                }
            }
        }
        Item {
            id:body;x:103;y:72;width:parent.width-109;height:parent.height-80-(status.visible ? 16 : 0)
            MouseArea { anchors.fill:parent;acceptedButtons:Qt.LeftButton|Qt.RightButton;onClicked:mouse=>{root.forceActiveFocus();if(mouse.button===Qt.RightButton){context.x=Math.min(design.width-context.width-5,body.x+mouse.x);context.y=Math.min(design.height-context.height-5,body.y+mouse.y);context.open()}else root.model.selected=[]} }
            DropArea { anchors.fill:parent;enabled:root.model.writable && !root.model.busy;onDropped:drop=>{if(drop.hasUrls){root.model.action("drop",{uris:drop.urls.map(url=>String(url))});drop.acceptProposedAction()}} }
            GridView {
                id:grid;objectName:"files-grid";anchors.fill:parent;visible:root.model.viewMode==="icons";clip:true;cellWidth:55;cellHeight:74;model:root.model.entries;boundsBehavior:Flickable.StopAtBounds
                currentIndex:root.model.entries.findIndex(entry=>entry.id===root.model.selected[root.model.selected.length-1])
                onCurrentIndexChanged:if(currentIndex>=0)positionViewAtIndex(currentIndex,GridView.Contain)
                delegate: Item {
                    id:cell;required property var modelData;required property int index;width:55;height:74
                    Rectangle { x:1;y:1;width:53;height:65;radius:1;color:root.model.selected.indexOf(cell.modelData.id)>=0 ? Theme.fileSelection : hover.containsMouse ? Theme.fileHover : Theme.transparent;border.color:root.model.selected.indexOf(cell.modelData.id)>=0 ? Theme.accentDim : Theme.transparent }
                    Image { x:11;y:8;width:32;height:32;source:root.iconSource(cell.modelData);sourceSize.width:64;sourceSize.height:64;fillMode:Image.PreserveAspectFit;asynchronous:true }
                    HudText { x:0;y:43;width:55;height:16;font.pixelSize:Theme.fileCaption;text:cell.modelData.name;horizontalAlignment:Text.AlignHCenter }
                    Item {
                        id:dragProxy;width:1;height:1
                        Drag.active:hover.drag.active
                        Drag.source:cell
                        Drag.dragType:Drag.Automatic
                        Drag.supportedActions:Qt.CopyAction
                        Drag.imageSource:root.iconSource(cell.modelData)
                        Drag.mimeData:({"text/uri-list":root.model.selected.map(id=>(root.model.entries.find(entry=>entry.id===id)||{}).uri||"").filter(uri=>uri.indexOf("file:")===0).join("\r\n")})
                    }
                    MouseArea { id:hover;objectName:"files-entry-"+cell.index;anchors.fill:parent;hoverEnabled:true;acceptedButtons:Qt.LeftButton|Qt.RightButton
                        drag.target:dragProxy;drag.threshold:8
                        onPressed:mouse=>{if(root.model.selected.indexOf(cell.modelData.id)<0 || (mouse.modifiers&(Qt.ControlModifier|Qt.ShiftModifier)))root.model.select(cell.modelData.id,cell.index,mouse.modifiers)}
                        onClicked:mouse=>{if(mouse.button===Qt.LeftButton && !(mouse.modifiers&(Qt.ControlModifier|Qt.ShiftModifier)))root.model.select(cell.modelData.id,cell.index,mouse.modifiers);root.forceActiveFocus();if(mouse.button===Qt.RightButton){context.x=Math.min(design.width-context.width-5,body.x+cell.x+mouse.x);context.y=Math.min(design.height-context.height-5,body.y+cell.y+mouse.y);context.open()}}
                        onDoubleClicked:root.model.activate(cell.modelData)
                    }
                    DropArea { anchors.fill:parent;enabled:cell.modelData.directory && root.model.writable && !root.model.busy;onDropped:drop=>{if(drop.hasUrls && drop.source!==cell){root.model.action("drop",{target:cell.modelData.id,uris:drop.urls.map(url=>String(url))});drop.acceptProposedAction()}} }
                    HudToolTip { visible:hover.containsMouse;delay:800;text:cell.modelData.name }
                }
                Controls.ScrollBar.vertical:Controls.ScrollBar {width:3;contentItem:Rectangle{color:Theme.accentDim;implicitWidth:3} background:Item{}}
            }
            ListView {
                anchors.fill:parent;visible:root.model.viewMode==="list";clip:true;model:root.model.entries;boundsBehavior:Flickable.StopAtBounds
                currentIndex:root.model.entries.findIndex(entry=>entry.id===root.model.selected[root.model.selected.length-1])
                onCurrentIndexChanged:if(currentIndex>=0)positionViewAtIndex(currentIndex,ListView.Contain)
                delegate: Item {
                    id:listCell;required property var modelData;required property int index;width:ListView.view.width;height:24
                    Rectangle {anchors.fill:parent;color:root.model.selected.indexOf(listCell.modelData.id)>=0 ? Theme.fileSelection : Theme.transparent}
                    Image{x:3;y:4;width:16;height:16;source:root.iconSource(listCell.modelData);fillMode:Image.PreserveAspectFit}
                    HudText{x:25;width:parent.width-85;height:24;font.pixelSize:Theme.fileCaption;text:listCell.modelData.name}
                    HudText{anchors.right:parent.right;width:55;height:24;font.pixelSize:Theme.fileCaption;color:Theme.textSecondary;text:listCell.modelData.directory ? "" : listCell.modelData.size<1024 ? listCell.modelData.size+" B" : Math.round(listCell.modelData.size/1024)+" KB";horizontalAlignment:Text.AlignRight}
                    MouseArea{anchors.fill:parent;onClicked:mouse=>{root.model.select(listCell.modelData.id,listCell.index,mouse.modifiers);root.forceActiveFocus()} onDoubleClicked:root.model.activate(listCell.modelData)}
                }
                Controls.ScrollBar.vertical:Controls.ScrollBar{width:3}
            }
            HudText { anchors.centerIn:parent;visible:!root.model.busy && root.model.entries.length===0 && root.model.error.length===0;font.pixelSize:Theme.fileCaption;color:Theme.textMuted;text:root.model.query ? "일치하는 파일이 없습니다" : "빈 폴더" }
        }
        HudText { id:status;x:104;y:parent.height-21;width:parent.width-115;height:17;font.pixelSize:Theme.fileCaption;color:root.model.error ? Theme.danger : Theme.textSecondary;visible:root.model.busy || root.model.error.length>0 || Boolean(root.model.current && root.model.current.truncated);text:root.model.error || (root.model.busy ? "처리 중…" : "20,000개까지 표시합니다. 더 큰 폴더는 메뉴에서 Nemo로 여세요.") }
        Controls.Popup {
            id:context;width:166;padding:4;closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
            background:Rectangle{color:Theme.background;border.color:Theme.accentDim;radius:1}
            contentItem:Column{
                Repeater{
                    model:[{text:"열기",action:"open",enabled:root.model.selected.length>0},
                        {text:"복사",action:"copy",enabled:root.model.selected.length>0 && !root.model.inTrash},
                        {text:"잘라내기",action:"cut",enabled:root.model.selected.length>0 && root.model.writable},
                        {text:"붙여넣기",action:"paste",enabled:root.model.writable},
                        {text:"이름 변경",action:"rename",enabled:root.model.writable && root.model.selected.length===1},
                        {text:"새 폴더",action:"folder",enabled:root.model.writable},
                        {text:root.model.inTrash ? "원래 위치로 복원" : "휴지통으로 이동",action:root.model.inTrash ? "restore" : "trash",enabled:root.model.selected.length>0},
                        {text:"숨김 파일 표시",action:"hidden",enabled:true},{text:"이름순 정렬",action:"sort",enabled:true},
                        {text:"보조 앱 Nemo로 열기",action:"nemo",enabled:root.model.current!==null}]
                    delegate:Controls.ItemDelegate{
                        required property var modelData;width:158;height:22;enabled:modelData.enabled
                        contentItem:HudText{text:parent.modelData.text;font.pixelSize:Theme.fileCaption;color:parent.enabled ? Theme.textPrimary : Theme.textMuted}
                        background:Rectangle{color:parent.hovered ? Theme.surfaceElevated : Theme.transparent}
                        onClicked:{context.close();const a=modelData.action;if(a==="rename"||a==="folder")root.showDialog(a);else if(a==="hidden")root.model.showHidden=!root.model.showHidden;else if(a==="sort")root.model.sortBy="name";else if(a==="open")root.activateSelected();else root.model.action(a)}
                    }
                }
            }
        }
        Controls.Popup {
            id:form;property string action:"folder";x:(design.width-width)/2;y:Math.max(65,(design.height-height)/2);width:260;height:112;padding:10;modal:true;focus:true
            background:Rectangle{color:Theme.background;border.color:Theme.accentDim;radius:1}
            contentItem:Item{
                HudText{text:form.action==="rename" ? "이름 변경" : "새 폴더";font.pixelSize:Theme.fileText;height:20}
                Rectangle{x:0;y:24;width:238;height:26;color:Theme.surface;border.color:Theme.border
                    TextInput{id:formInput;objectName:"files-name-input";anchors.fill:parent;anchors.margins:5;clip:true;font.family:Theme.fontMono;font.pixelSize:Theme.fileText;color:Theme.textPrimary;selectByMouse:true;onAccepted:{root.model.action(form.action,{name:text});form.close();root.forceActiveFocus()}}
                }
                Controls.Button{x:152;y:60;width:86;height:24;text:"확인";onClicked:{root.model.action(form.action,{name:formInput.text});form.close();root.forceActiveFocus()} contentItem:HudText{text:parent.text;font.pixelSize:Theme.fileText;horizontalAlignment:Text.AlignHCenter} background:Rectangle{color:Theme.surfaceElevated;border.color:Theme.accentDim}}
            }
        }
    }
}
