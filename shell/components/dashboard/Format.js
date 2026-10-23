.pragma library
function emptySnapshot() {
    return {cpu: {name: "", percent: null}, memory: {used: null, total: null, percent: null}, gpu: {name: "", percent: null},
        temperature: {value: null, label: "", critical: null}, storage: [], storageReady: false,
        network: {interface: "", down: null, up: null, interfaces: []}}
}
function valid(value) { return typeof value === "number" && Number.isFinite(value) }
function percent(value) { return valid(value) ? Math.round(value) + "%" : "N/A" }
function bytes(value) {
    if (!valid(value) || value < 0) return "N/A"
    const units = ["B", "KiB", "MiB", "GiB", "TiB"]
    let unit = 0
    while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit++ }
    return (unit === 0 ? Math.round(value) : value.toFixed(value >= 100 ? 0 : 1)) + " " + units[unit]
}
function rate(value) { return valid(value) && value >= 0 ? bytes(value) + "/s" : "N/A" }
function fraction(value) { return valid(value) ? Math.max(0, Math.min(1, value / 100)) : -1 }
