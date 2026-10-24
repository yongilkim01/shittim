import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"

FocusScope {
    id: root
    property var entries: []
    property var saved: ({})
    property var iconSource: function(entry) { return "" }
    property string error: ""
    property bool busy: false
    readonly property alias model: selection
    signal requested(string operation,var values)
    signal positionsSaved(var positions)
    signal refreshRequested()
    DesktopModel { id:selection; entries:root.entries; saved:root.saved; areaWidth:root.width; areaHeight:root.height; onPositionsChangedByUser: values=>root.positionsSaved(values) }
    function request(action) {
        menu.close()
        if (action === "rename" || action === "folder") { prompt.operation=action; prompt.open(); field.text=action === "rename" && selection.selected.length===1 ? (entries.find(entry=>entry.id===selection.selected[0]) || {}).name || "" : ""; field.forceActiveFocus(); field.selectAll() }
        else root.requested(action,{ids:selection.selected})
    }
    Keys.onPressed: event=>{
        if (event.key === Qt.Key_F5) { root.refreshRequested(); event.accepted=true }
        else if (event.key === Qt.Key_Return && selection.selected.length) { root.request("open"); event.accepted=true }
        else if (event.key === Qt.Key_Delete && selection.selected.length) { root.request("trash"); event.accepted=true }
        else if (event.key === Qt.Key_F2 && selection.selected.length===1) { root.request("rename"); event.accepted=true }
        else if (event.modifiers & Qt.ControlModifier) {
            const actions={}; actions[Qt.Key_C]="copy"; actions[Qt.Key_X]="cut"; actions[Qt.Key_V]="paste"
            if (actions[event.key]) { root.request(actions[event.key]); event.accepted=true }
            else if (event.key === Qt.Key_A) { selection.selected=entries.map(entry=>entry.id); event.accepted=true }
        }
    }
    MouseArea {
        id:blank; anchors.fill:parent; acceptedButtons:Qt.LeftButton|Qt.RightButton
        property real startX:0; property real startY:0
        onPressed: mouse=>{ root.forceActiveFocus(); startX=mouse.x; startY=mouse.y; if (!(mouse.modifiers&Qt.ControlModifier)) selection.selected=[] }
        onPositionChanged: mouse=>{ if (pressedButtons&Qt.LeftButton) selection.selectRect(Math.min(startX,mouse.x),Math.min(startY,mouse.y),Math.abs(mouse.x-startX),Math.abs(mouse.y-startY),Boolean(mouse.modifiers&Qt.ControlModifier)) }
        onClicked: mouse=>{ if (mouse.button===Qt.RightButton) { menu.x=Math.max(0,Math.min(root.width-210,mouse.x)); menu.y=Math.max(0,Math.min(root.height-300,mouse.y)); menu.open() } }
    }
    Rectangle {
        visible:blank.pressed && (blank.pressedButtons&Qt.LeftButton) && Math.abs(blank.mouseX-blank.startX)+Math.abs(blank.mouseY-blank.startY)>4
        x:Math.min(blank.startX,blank.mouseX); y:Math.min(blank.startY,blank.mouseY)
        width:Math.abs(blank.mouseX-blank.startX); height:Math.abs(blank.mouseY-blank.startY)
        color:Theme.selectionFill; border.color:Theme.accent
    }
    DropArea {
        anchors.fill:parent
        onDropped: drop=>{
            if (drop.source && drop.source.desktopIcon) { drop.acceptProposedAction(); return }
            if (drop.hasUrls) { root.requested("drop",{uris:drop.urls.map(url=>String(url))}); drop.acceptProposedAction() }
        }
    }
    Repeater {
        model:root.entries
        delegate:Item {
            id:icon; required property var modelData; required property int index
            property bool desktopIcon:true
            property real originX:0; property real originY:0
            readonly property var placement:selection.position(modelData,index)
            x:placement[0]; y:placement[1]; width:Theme.desktopCellWidth; height:Theme.desktopCellHeight
            Drag.active: mouse.drag.active
            Drag.source: icon
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            Drag.mimeData: ({"text/uri-list":selection.selected.map(id=>(root.entries.find(entry=>entry.id===id)||{}).uri||"").filter(uri=>uri.indexOf("file:")===0).join("\r\n")})
            Rectangle { anchors.fill:parent; anchors.margins:2; color:selection.selected.indexOf(icon.modelData.id)>=0 ? Theme.selectionFill : Theme.transparent; border.color:selection.selected.indexOf(icon.modelData.id)>=0 ? Theme.accentDim : Theme.transparent }
            Image { x:22; y:8; width:44; height:44; source:root.iconSource(icon.modelData); sourceSize.width:88; sourceSize.height:88; asynchronous:true }
            HudText { x:3; y:56; width:parent.width-6; height:32; text:icon.modelData.name; font.pixelSize:10; horizontalAlignment:Text.AlignHCenter; wrapMode:Text.Wrap; maximumLineCount:2; style:Text.Outline; styleColor:Theme.background }
            MouseArea {
                id:mouse; objectName:"desktop-icon-"+icon.modelData.id; anchors.fill:parent; acceptedButtons:Qt.LeftButton|Qt.RightButton
                drag.target:icon; drag.threshold:8
                onPressed: event=>{ root.forceActiveFocus(); selection.select(icon.modelData.id,Boolean(event.modifiers&Qt.ControlModifier)); icon.originX=icon.x; icon.originY=icon.y }
                onReleased: event=>{
                    if (event.button===Qt.LeftButton) {
                        const dx=icon.x-icon.originX,dy=icon.y-icon.originY
                        icon.x=Qt.binding(()=>icon.placement[0]); icon.y=Qt.binding(()=>icon.placement[1])
                        if (Math.abs(dx)+Math.abs(dy)>4) selection.move(dx,dy)
                    }
                }
                onClicked: event=>{ if (event.button===Qt.RightButton) { const point=icon.mapToItem(root,event.x,event.y); menu.x=Math.max(0,Math.min(root.width-210,point.x)); menu.y=Math.max(0,Math.min(root.height-300,point.y)); menu.open() } }
                onDoubleClicked: event=>{ if (event.button===Qt.LeftButton) root.request("open") }
            }
            DropArea { anchors.fill:parent; enabled:icon.modelData.directory
                onDropped: drop=>{ if (drop.hasUrls && !(drop.source===icon)) { root.requested("drop",{target:icon.modelData.id,uris:drop.urls.map(url=>String(url))}); drop.acceptProposedAction() } }
            }
        }
    }
    Controls.Popup {
        id:menu; width:210; padding:6; closePolicy:Controls.Popup.CloseOnEscape|Controls.Popup.CloseOnPressOutside
        background:ControlFrame { fillColor:Theme.floatingSurface; strokeColor:Theme.accentDim }
        contentItem:Column {
            spacing:3
            Repeater {
                model:selection.selected.length ? [{text:"열기",op:"open"},{text:"복사",op:"copy"},{text:"잘라내기",op:"cut"},{text:"이름 변경",op:"rename"},{text:"휴지통으로 이동",op:"trash"}] : [{text:"바탕화면 폴더 열기",op:"open-desktop"},{text:"붙여넣기",op:"paste"},{text:"새 폴더",op:"folder"}]
                HudButton {
                    required property var modelData; width:198; height:29; text:modelData.text
                    enabled:!root.busy && (modelData.op!=="rename" || selection.selected.length===1) && (modelData.op==="open" || !root.entries.some(entry=>selection.selected.indexOf(entry.id)>=0 && entry.special))
                    onClicked:root.request(modelData.op)
                }
            }
            HudButton { width:198; height:29; text:"새로고침"; onClicked:{menu.close();root.refreshRequested()} }
        }
    }
    Controls.Popup {
        id:prompt; property string operation:""; width:Math.min(340,root.width); height:112; anchors.centerIn:parent; modal:true; closePolicy:Controls.Popup.CloseOnEscape
        background:ControlFrame { fillColor:Theme.floatingSurface; strokeColor:Theme.accentDim }
        HudInput { id:field; x:10; y:10; width:prompt.width-20; height:36; onAccepted:submit.clicked() }
        HudButton { id:submit; x:10; y:58; width:120; height:32; text:"확인"; onClicked:{root.requested(prompt.operation,{ids:selection.selected,name:field.text});prompt.close()} }
        HudButton { x:prompt.width-130; y:58; width:120; height:32; text:"취소"; onClicked:prompt.close() }
    }
    HudText { anchors.bottom:parent.bottom; anchors.horizontalCenter:parent.horizontalCenter; width:Math.min(parent.width,700); height:44; visible:root.error.length>0; text:root.error; color:Theme.danger; wrapMode:Text.Wrap; horizontalAlignment:Text.AlignHCenter }
}
