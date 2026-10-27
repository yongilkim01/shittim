import QtQuick

QtObject {
    id:root
    required property var service
    property bool active:false
    property var retained:null
    function sync() {
        const next=active ? service : null
        if(retained===next)return
        if(retained && typeof retained.release==="function")retained.release(root)
        retained=next
        if(retained)retained.retain(root)
    }
    onActiveChanged:sync()
    onServiceChanged:sync()
    Component.onCompleted:sync()
    Component.onDestruction:if(retained && typeof retained.release==="function")retained.release(root)
}
