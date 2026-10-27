import QtQuick

QtObject {
    property var consumers: []
    readonly property bool active: consumers.length>0
    function retain(consumer) { if(consumer && consumers.indexOf(consumer)<0)consumers=consumers.concat([consumer]) }
    function release(consumer) { consumers=consumers.filter(value=>value!==consumer) }
}
