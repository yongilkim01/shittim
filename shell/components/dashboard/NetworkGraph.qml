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
        c.lineWidth = 1; c.strokeStyle = Theme.frameLine
        for (let i = 0; i < 4; i++) { const y = Math.round(i * (h - 1) / 3) + 0.5; c.beginPath(); c.moveTo(0, y); c.lineTo(w, y); c.stroke() }
        if (samples.length < 2) return
        const begin = samples[0].time, span = samples[samples.length - 1].time - begin
        if (span <= 0) return
        let maximum = 1
        for (const sample of samples) maximum = Math.max(maximum, sample.down || 0, sample.up || 0)
        const point = (sample, key) => [(sample.time - begin) * (w - 1) / span, h - 2 - sample[key] * (h - 4) / maximum]
        // Download gets a filled area under its line; upload stays a thin dim line.
        for (const key of ["down", "up"]) {
            const runs = []
            let run = []
            for (const sample of samples) {
                if (sample[key] === null || !Number.isFinite(sample[key])) { if (run.length) runs.push(run); run = []; continue }
                run.push(point(sample, key))
            }
            if (run.length) runs.push(run)
            for (const line of runs) {
                if (key === "down" && line.length > 1) {
                    const fill = c.createLinearGradient(0, 0, 0, h)
                    fill.addColorStop(0, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.28))
                    fill.addColorStop(1, Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0))
                    c.beginPath(); c.moveTo(line[0][0], h)
                    for (const p of line) c.lineTo(p[0], p[1])
                    c.lineTo(line[line.length - 1][0], h); c.closePath()
                    c.fillStyle = fill; c.fill()
                }
                c.strokeStyle = key === "down" ? Theme.accent : Theme.accentDim; c.lineWidth = key === "down" ? 1.2 : 0.8
                c.beginPath(); c.moveTo(line[0][0], line[0][1])
                for (const p of line) c.lineTo(p[0], p[1])
                c.stroke()
            }
        }
    }
}
