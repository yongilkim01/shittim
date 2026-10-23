.pragma library

function text(value, limit) {
    return String(value || "").replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u202a-\u202e\u2066-\u2069]/g, "").slice(0, limit)
}
function category(hints) {
    // Categories are hints supplied by the sender, not authenticated identities.
    const value = text((hints || {}).category, 128).toLowerCase()
    return /^(device|system|network)(\.|$)/.test(value) ? "system" : "app"
}
function iconName(value) { return /^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$/.test(value || "") ? value : "" }
function image(value) {
    // Only the native notification image-data provider. No remote URLs or arbitrary files.
    return /^image:\/\/qsimage\/\d+\/\d+$/.test(value || "") ? value : ""
}
function snapshot(n, resolveIcon) {
    return {id: n.id, summary: text(n.summary, 512), body: text(n.body, 8192),
        appName: text(n.appName, 128), desktopEntry: text(n.desktopEntry, 256),
        icon: resolveIcon(iconName(n.appIcon)), image: image(n.image),
        category: category(n.hints), urgency: Number(n.urgency), transient: !!n.transient,
        timeout: Number(n.expireTimeout), restored: !!n.lastGeneration,
        actions: n.actions.slice(0, 12).map(action => ({id: text(action.identifier, 256), text: text(action.text, 128)}))}
}
function relative(timestamp, now) {
    const seconds = Math.max(0, Math.floor((now - timestamp) / 1000))
    if (seconds < 60) return "now"
    if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
    if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
    return Math.floor(seconds / 86400) + "d ago"
}
