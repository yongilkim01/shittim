function text(value) { return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]/g, " ").slice(0, 2048) : "" }
function artwork(value) {
    if (typeof value !== "string" || value.length > 8192 || /[\u0000-\u0020\u007f]/.test(value)) return ""
    // Local files and web images only. No data:, qrc:, provider URLs or credentials.
    if (/^file:\/\/(?:localhost)?\//i.test(value)) return value
    if (/^https?:\/\/[^/@?#]+(?:[/?#]|$)/i.test(value)) return value
    return ""
}
function time(value) {
    if (!Number.isFinite(value) || value < 0) return "--:--"
    const seconds = Math.floor(value), hours = Math.floor(seconds / 3600)
    return (hours > 0 ? hours + ":" : "") + String(Math.floor(seconds / 60) % (hours > 0 ? 60 : Infinity)).padStart(2, "0") + ":" + String(seconds % 60).padStart(2, "0")
}
function aliases(app, overrides) {
    if (overrides && Object.prototype.hasOwnProperty.call(overrides, app.id)) return overrides[app.id]
    return [app.id.replace(/\.desktop$/, ""), app.startupWMClass || ""].filter(value => value.length > 0)
}
function matches(app, windows, applications, overrides) {
    const keys = aliases(app, overrides)
    return windows.filter(window => {
        const ids = [window.appId || "", window.className || "", window.initialClass || ""].filter(value => value.length > 0)
        const shared = keys.filter(key => ids.indexOf(key) >= 0)
        return shared.some(key => !applications.some(other => other.id !== app.id && aliases(other, overrides).indexOf(key) >= 0))
    })
}
function preferred(windows, recent) {
    return windows.slice().sort((a, b) => {
        const aRank = recent.indexOf(a.address), bRank = recent.indexOf(b.address)
        return Number(b.activated) - Number(a.activated) || (aRank < 0 ? 999 : aRank) - (bRank < 0 ? 999 : bRank) || a.address.localeCompare(b.address)
    })
}
