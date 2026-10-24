import QtQuick
import "../../ui"

QtObject {
    id: root
    property var entries: []
    property var selected: []
    property var saved: ({})
    property real areaWidth: 800
    property real areaHeight: 600
    readonly property int rows: Math.max(1,Math.floor(areaHeight/Theme.desktopCellHeight))
    signal positionsChangedByUser(var positions)
    function position(entry,index) {
        const p=saved[entry.id] || [Math.floor(index/rows)*Theme.desktopCellWidth, (index%rows)*Theme.desktopCellHeight]
        return [Math.max(0,Math.min(areaWidth-Theme.desktopCellWidth,p[0])),Math.max(0,Math.min(areaHeight-Theme.desktopCellHeight,p[1]))]
    }
    function select(id,add) {
        if (!add) { if (selected.indexOf(id)<0) selected=[id]; return }
        selected=selected.indexOf(id)<0 ? selected.concat([id]) : selected.filter(value=>value!==id)
    }
    function selectRect(x,y,w,h,add) {
        const hits=entries.filter((entry,index)=>{ const p=position(entry,index); return p[0]<x+w && p[0]+Theme.desktopCellWidth>x && p[1]<y+h && p[1]+Theme.desktopCellHeight>y }).map(entry=>entry.id)
        selected=add ? selected.concat(hits.filter(id=>selected.indexOf(id)<0)) : hits
    }
    function move(dx,dy) {
        const copy=Object.assign({},saved)
        entries.forEach((entry,index)=>{
            if (selected.indexOf(entry.id)<0) return
            const p=position(entry,index)
            copy[entry.id]=[Math.max(0,Math.min(areaWidth-Theme.desktopCellWidth,p[0]+dx)),Math.max(0,Math.min(areaHeight-Theme.desktopCellHeight,p[1]+dy))]
        })
        saved=copy; positionsChangedByUser(copy)
    }
    onEntriesChanged: selected=selected.filter(id=>entries.some(entry=>entry.id===id))
}
