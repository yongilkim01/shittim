import QtQuick
import QtQuick.Window

Window {
        id:window;
        required property var browserModel
        property var iconSource: function(entry) { return "" }
        signal minimizeRequested()
        visible:true;title:(window.browserModel.current ? window.browserModel.current.name+" — " : "")+"Shittim Files"
        flags:Qt.Window|Qt.FramelessWindowHint|Qt.NoDropShadowWindowHint;color:"transparent"
        width:Math.min(Screen.desktopAvailableWidth-24,Math.max(440,Math.min(860,Screen.width*0.34)))
        height:Math.min(Screen.desktopAvailableHeight-32,width*326/440)
        minimumWidth:Math.min(400,Screen.desktopAvailableWidth-24);minimumHeight:Math.min(280,Screen.desktopAvailableHeight-32)
        FilesView {
            id:view;anchors.fill:parent;model:window.browserModel;iconSource:window.iconSource;maximized:window.visibility===Window.Maximized;focus:true
            onDragRequested:window.startSystemMove()
            onMinimizeRequested:window.minimizeRequested()
            onMaximizeRequested:{if(window.visibility===Window.Maximized)window.showNormal();else window.showMaximized()}
            onCloseRequested:window.close()
        }
        Repeater {
            model:[Qt.LeftEdge,Qt.RightEdge,Qt.TopEdge,Qt.BottomEdge,Qt.LeftEdge|Qt.TopEdge,Qt.RightEdge|Qt.TopEdge,Qt.LeftEdge|Qt.BottomEdge,Qt.RightEdge|Qt.BottomEdge]
            delegate:MouseArea {
                required property int modelData
                objectName:"files-resize-"+modelData
                readonly property bool edgeLeft:Boolean(modelData & Qt.LeftEdge)
                readonly property bool edgeRight:Boolean(modelData & Qt.RightEdge)
                readonly property bool edgeTop:Boolean(modelData & Qt.TopEdge)
                readonly property bool edgeBottom:Boolean(modelData & Qt.BottomEdge)
                x:edgeLeft ? 0 : edgeRight ? window.width-5 : 5;y:edgeTop ? 0 : edgeBottom ? window.height-5 : 5
                width:edgeLeft||edgeRight ? 5 : window.width-10;height:edgeTop||edgeBottom ? 5 : window.height-10
                enabled:window.visibility!==Window.Maximized;z:100
                cursorShape:(edgeLeft||edgeRight)&&(edgeTop||edgeBottom) ? (edgeLeft===edgeTop ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : edgeLeft||edgeRight ? Qt.SizeHorCursor : Qt.SizeVerCursor
                onPressed:window.startSystemResize(modelData)
            }
        }
    }
