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
