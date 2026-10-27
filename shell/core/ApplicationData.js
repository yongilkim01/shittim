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
