.pragma library

// xdg-desktop-portal-hyprland custom picker protocol (same on v1.4.1 and later):
// input  XDPH_WINDOW_SHARING_LIST = repeated "<id>[HC>]<class>[HT>]<title>[HE>]<address>[HA>]"
//        XDPH_OUTPUT_SHARING_LIST = repeated "<name length>:<name>:<x>:<y>:<width>:<height>;" (newer xdph only)
// output "[SELECTION]<flags>/screen:<output>\n" or "[SELECTION]<flags>/window:<id>\n"; flag "r" allows a restore token.

function parseWindows(text) {
    const windows = []
    for (const entry of String(text || "").split("[HA>]")) {
        const classAt = entry.indexOf("[HC>]"), titleAt = entry.indexOf("[HT>]"), addressAt = entry.indexOf("[HE>]")
        if (classAt < 0 || titleAt < classAt || addressAt < titleAt) continue
        const id = entry.slice(0, classAt)
        if (!/^[0-9]+$/.test(id)) continue
        windows.push({id: id, appClass: entry.slice(classAt + 5, titleAt), title: entry.slice(titleAt + 5, addressAt), address: entry.slice(addressAt + 5)})
    }
    return windows
}

function parseOutputs(text) {
    const outputs = []
    const value = String(text || "")
    let at = 0
    while (at < value.length) {
        const colon = value.indexOf(":", at)
        const length = colon > at ? Number(value.slice(at, colon)) : NaN
        if (!Number.isInteger(length) || length <= 0) return outputs
        const name = value.substr(colon + 1, length)
        const end = value.indexOf(";", colon + 1 + length)
        const numbers = end < 0 ? [] : value.slice(colon + 2 + length, end).split(":").map(Number)
        if (name.length !== length || numbers.length !== 4 || numbers.some(number => !Number.isFinite(number))) return outputs
        outputs.push({name: name, x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3]})
        at = end + 1
    }
    return outputs
}

function selection(kind, value, remember) {
    const text = String(value)
    if (kind === "screen" && text.length > 0 && !/[\r\n]/.test(text)) return "[SELECTION]" + (remember ? "r" : "") + "/screen:" + text + "\n"
    if (kind === "window" && /^[0-9]+$/.test(text)) return "[SELECTION]" + (remember ? "r" : "") + "/window:" + text + "\n"
    return ""
}
