import QtQuick
import "../../ui"

Canvas {
    property string glyph: "folder"
    property color ink: Theme.textSecondary
    onGlyphChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c=getContext("2d"); c.reset(); c.scale(width/16,height/16)
        c.strokeStyle=ink; c.fillStyle=ink; c.lineWidth=1.15; c.lineCap="square"; c.lineJoin="miter"
        function line(points) { c.beginPath(); c.moveTo(points[0],points[1]); for(let i=2;i<points.length;i+=2)c.lineTo(points[i],points[i+1]); c.stroke() }
        if(glyph==="close") { line([5,5,11,11]); line([11,5,5,11]) }
        else if(glyph==="minimize") line([4,9,12,9])
        else if(glyph==="maximize") c.strokeRect(4.5,4.5,7,7)
        else if(glyph==="restore") { c.strokeRect(3.5,6.5,6,6); line([6,6,6,3.5,12.5,3.5,12.5,10,10,10]) }
        else if(glyph==="back") line([10,3,5,8,10,13])
        else if(glyph==="forward") line([6,3,11,8,6,13])
        else if(glyph==="home") { line([2,7,8,2,14,7]); line([4,6,4,14,7,14,7,10,10,10,10,14,12,14,12,6]) }
        else if(glyph==="search") { c.beginPath();c.arc(6.5,6.5,4,0,Math.PI*2);c.stroke();line([10,10,14,14]) }
        else if(glyph==="grid") for(let y=3;y<13;y+=6)for(let x=3;x<13;x+=6)c.strokeRect(x,y,4,4)
        else if(glyph==="list") for(let y=4;y<=12;y+=4){c.fillRect(2,y-1,2,2);line([7,y,14,y])}
        else if(glyph==="menu") for(let y=4;y<=12;y+=4){c.fillRect(4,y,1.5,1.5);c.fillRect(10,y,1.5,1.5)}
        else if(glyph==="trash") {line([3,4,13,4]);line([5,4,5,14,11,14,11,4]);line([6,3,6,2,10,2,10,3]);line([7,7,7,11]);line([9,7,9,11])}
        else if(glyph==="download") {line([8,2,8,11]);line([5,8,8,11,11,8]);line([3,11,3,14,13,14,13,11])}
        else if(glyph==="desktop") {c.strokeRect(2.5,2.5,11,8);line([8,11,8,14]);line([5,14,11,14])}
        else if(glyph==="drive") {c.strokeRect(4,2,8,12);line([6,11,10,11]);c.fillRect(9,4,1,1)}
        else if(glyph==="document") {line([4,2,10,2,13,5,13,14,4,14,4,2]);line([10,2,10,5,13,5])}
        else if(glyph==="image") {c.strokeRect(2.5,2.5,11,11);line([3,11,7,7,10,10,12,8,14,10]);c.fillRect(10,5,1,1)}
        else if(glyph==="video") {c.strokeRect(2,3,12,10);line([6,5,11,8,6,11,6,5])}
        else if(glyph==="music") {line([6,12,6,3,13,2,13,11]);c.strokeRect(3,11,3,3);c.strokeRect(10,10,3,3)}
        else if(glyph==="network") {c.strokeRect(6,2,4,4);line([8,6,8,9,3,9,3,11]);line([8,9,13,9,13,11]);c.strokeRect(1,11,4,3);c.strokeRect(11,11,4,3)}
        else {line([2,5,2,14,14,14,14,5,8,5,6,2,2,2,2,5])}
    }
}
