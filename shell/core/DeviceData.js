.pragma library

// PipeWire node classification shared by audio, microphone and screen-share services.
// Inputs are Quickshell PwNode objects or plain fixtures with the same fields.

function label(node) {
    if (!node) return ""
    return node.description || node.nickname || node.name || ""
}

function property(node, key) {
    const values = node && node.properties ? node.properties : null
    return values && values[key] !== undefined && values[key] !== null ? String(values[key]) : ""
}

// Audio/Source hardware or virtual inputs. Sink monitors are not separate PipeWire nodes.
function isMicrophone(node) {
    return !!node && !node.isSink && !node.isStream && node.audio !== null && node.audio !== undefined
}

// Stream/Input/Audio opened by an application. Peak meters and sink-monitor recorders are not microphone use.
// Until a node is ready its properties are missing, so a peak meter would briefly look like a recorder; tracking and
// then dropping it while PipeWire is still announcing it crashes Quickshell 0.3.2.
function isRecording(node) {
    if (!node || node.ready === false || node.isSink || !node.isStream || node.audio === null || node.audio === undefined) return false
    return property(node, "stream.monitor") !== "true" && property(node, "stream.capture.sink") !== "true"
}

// Chrome names its capture stream "Google Chrome input"; the user knows the app as "Google Chrome".
function applicationName(node) {
    const name = property(node, "application.name") || label(node)
    return name ? name.replace(/\s+input$/i, "") || name : "알 수 없는 앱"
}

function applicationNames(nodes) {
    const names = []
    for (const node of nodes) {
        const name = applicationName(node)
        if (names.indexOf(name) < 0) names.push(name)
    }
    return names
}

// xdg-desktop-portal-hyprland creates one Video/Source stream per screencast. The stream is named
// "xdph-streaming-<random>" (media.name), but PipeWire sets node.name to the portal's application name.
function isScreenCast(node) {
    const name = String(node && node.name || "")
    return !!node && !node.isStream && (name === "xdg-desktop-portal-hyprland" || name.indexOf("xdph-streaming-") === 0)
}
