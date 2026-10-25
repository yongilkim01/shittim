// Repository assets live outside Quickshell's intercepted QML config root.
function fileUrl(path) {
    let normalized = String(path).replace(/\\/g, "/")
    if (/^[A-Za-z]:\//.test(normalized)) normalized = "/" + normalized
    if (normalized.indexOf("/") !== 0) return ""
    return "file://" + normalized.split("/").map((part, index) =>
        index === 1 && /^[A-Za-z]:$/.test(part) ? part : encodeURIComponent(part)).join("/")
}

function asset(shellDirectory, relative) {
    return fileUrl(shellDirectory + "/../assets/" + relative)
}
