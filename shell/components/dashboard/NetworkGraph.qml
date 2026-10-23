import QtQuick
import "../../ui"

Canvas {
    id: root
    property var samples: []
    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext("2d"), w = width, h = height
        c.clearRect(0, 0, w, h)
        c.lineWidth = 0.5; c.strokeStyle = Theme.border
        for (let i = 0; i < 4; i++) { c.beginPath(); c.moveTo(0, i * (h - 1) / 3); c.lineTo(w, i * (h - 1) / 3); c.stroke() }
        if (samples.length < 2) return
        const begin = samples[0].time, span = samples[samples.length - 1].time - begin
        if (span <= 0) return
        let maximum = 1
        for (const sample of samples) maximum = Math.max(maximum, sample.down || 0, sample.up || 0)
        for (const key of ["down", "up"]) {
            c.strokeStyle = key === "down" ? Theme.accent : Theme.accentDim; c.lineWidth = 0.8
            c.beginPath()
            let connected = false
            for (const sample of samples) {
                if (sample[key] === null || !Number.isFinite(sample[key])) { connected = false; continue }
                const x = (sample.time - begin) * (w - 1) / span, y = h - 2 - sample[key] * (h - 4) / maximum
                if (connected) c.lineTo(x, y); else c.moveTo(x, y)
                connected = true
            }
            c.stroke()
        }
    }
}
