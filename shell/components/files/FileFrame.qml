import QtQuick
import QtQuick.Shapes
import "../../ui"

Shape {
    id: root
    objectName: "files-frame"
    property bool maximized: false
    // Keep the widest (5px) glow stroke inside the native window on every side.
    readonly property real edgeInset: 2.5
    readonly property string outline: {
        const e=edgeInset,w=width-e,h=height-e,cut=maximized ? 0 : 6
        return "M "+(e+cut)+" "+e+" H "+(w-cut)+" L "+w+" "+(e+cut)+" V "+(h-cut)+" L "+(w-cut)+" "+h+" H "+e+" V "+(e+cut)+" Z"
    }
    clip: true
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        strokeWidth: 5; strokeColor: Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,0.06)
        fillGradient: LinearGradient {
            x1: 0; y1: 0; x2: root.width; y2: root.height
            GradientStop { position: 0; color: Theme.fileGradientStart }
            GradientStop { position: 1; color: Theme.fileGradientEnd }
        }
        PathSvg { path: root.outline }
    }
    ShapePath {
        strokeWidth: 3; strokeColor: Qt.rgba(Theme.accent.r,Theme.accent.g,Theme.accent.b,0.16); fillColor: "transparent"
        PathSvg { path: root.outline }
    }
    ShapePath {
        strokeWidth: 1; strokeColor: Theme.fileFrame; fillColor: "transparent"
        PathSvg { path: root.outline }
    }
}
