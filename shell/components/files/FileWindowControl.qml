import QtQuick
import QtQuick.Shapes
import "../../ui"

Shape {
    id: root
    objectName: "files-control-vector"
    property string glyph: "maximize"
    property color ink: Theme.accent
    readonly property real slot: Math.min(width,height)
    readonly property real inkExtent: slot*2/3
    readonly property real inkStroke: slot/15
    readonly property string outline: {
        const edge=slot/6, far=slot-edge, half=inkStroke/2, mid=slot/2
        if(glyph==="minimize")return "M "+edge+" "+mid+" H "+far
        if(glyph==="close") {
            const inset=half/Math.sqrt(2),a=edge+inset,b=far-inset
            return "M "+a+" "+a+" L "+b+" "+b+" M "+b+" "+a+" L "+a+" "+b
        }
        if(glyph==="restore") {
            const offset=inkExtent/4,a=edge+half,b=far-offset-half,c=edge+offset+half,d=far-half
            return "M "+a+" "+c+" H "+b+" V "+d+" H "+a+" Z M "+c+" "+(edge+offset-half)+" V "+a+" H "+d+" V "+b+" H "+(far-offset+half)
        }
        const a=edge+half,b=far-half
        return "M "+a+" "+a+" H "+b+" V "+b+" H "+a+" Z"
    }
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeColor: root.ink; strokeWidth: root.inkStroke; fillColor: "transparent"
        capStyle: ShapePath.FlatCap; joinStyle: ShapePath.MiterJoin
        PathSvg { path: root.outline }
    }
}
