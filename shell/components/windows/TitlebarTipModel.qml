import QtQuick

QtObject {
    property string owner: ""
    property string action: ""
    property int monitorId: -1
    property rect anchorRect: Qt.rect(0,0,0,0)
    property bool opened: false
    readonly property bool active: owner.length>0
    readonly property string label: ({minimize:"최소화",maximize:"최대화",restore:"복원",close:"닫기"})[action] || ""
    function clear() { owner="";action="";monitorId=-1;opened=false }
    function accept(payload) {
        const fields=String(payload).split(","),address=fields[0].toLowerCase()
        if(!/^[0-9a-f]{1,16}$/.test(address))return false
        if(fields.length===2 && fields[1]==="leave") { if(owner===address)clear();return false }
        if(fields.length!==7 || ["minimize","maximize","restore","close"].indexOf(fields[1])<0 || fields.slice(2).some(value=>!value.trim()))return false
        const values=fields.slice(2).map(Number)
        if(values.some(value=>!Number.isFinite(value)) || !Number.isInteger(values[0]) || values[0]<0 || values.slice(1).some(value=>Math.abs(value)>100000) || values[3]<=0 || values[4]<=0)return false
        const changed=owner!==address || action!==fields[1] || monitorId!==values[0]
        if(changed)opened=false
        owner=address;action=fields[1];monitorId=values[0];anchorRect=Qt.rect(values[1],values[2],values[3],values[4])
        return changed
    }
    function reveal() { if(active)opened=true }
    function position(screenWidth,screenHeight,tipWidth,tipHeight) {
        const below=anchorRect.y+anchorRect.height+4
        return Qt.point(Math.max(0,Math.min(Math.max(0,screenWidth-tipWidth),anchorRect.x+(anchorRect.width-tipWidth)/2)),
            Math.max(0,Math.min(Math.max(0,screenHeight-tipHeight),below+tipHeight>screenHeight ? anchorRect.y-tipHeight-4 : below)))
    }
}
