.pragma library
.import "DeviceData.js" as Devices

// Audio page logic without Quickshell types: nodes are PwNode objects or plain fixtures with the same fields
// (id, name, description, nickname, properties, audio {volume, muted}).

function label(node) { return Devices.label(node) }

// What kind of device a node is, from the properties PipeWire actually sets (bus, api, form factor, node name).
function kind(node, input) {
    const name = String(node && node.name || "").toLowerCase()
    const prop = key => Devices.property(node, key).toLowerCase()
    const form = prop("device.form-factor"), icon = prop("device.icon-name"), bus = prop("device.bus"), api = prop("device.api")
    if (api === "bluez5" || bus === "bluetooth" || name.indexOf("bluez") === 0 || icon.indexOf("bluetooth") >= 0)
        return {glyph: input ? "󰋎" : "󰂯", label: "Bluetooth"}
    if (form === "headset" || icon.indexOf("headset") >= 0) return {glyph: "󰋎", label: "헤드셋"}
    if (form === "headphone" || icon.indexOf("headphone") >= 0) return {glyph: "󰋋", label: "헤드폰"}
    if (name.indexOf("hdmi") >= 0 || name.indexOf("displayport") >= 0 || prop("device.profile.name").indexOf("hdmi") >= 0)
        return {glyph: "󰡁", label: "HDMI·DisplayPort"}
    if (bus === "usb" || name.indexOf(".usb-") >= 0 || name.indexOf("_usb") >= 0) return {glyph: "󰕓", label: "USB"}
    if (input) return {glyph: "󰍬", label: "마이크"}
    return {glyph: "󰓃", label: "스피커"}
}

// Left/right balance in [-1, 1] from per-channel volumes; null when the device has no separate left and right.
function balance(volumes, left, right) {
    if (!volumes || !left.length || !right.length) return null
    const avg = indexes => indexes.reduce((sum, i) => sum + (volumes[i] || 0), 0) / indexes.length
    const l = avg(left), r = avg(right), top = Math.max(l, r)
    return top <= 0 ? 0 : Math.max(-1, Math.min(1, (r - l) / top))
}

// Per-channel volumes for a balance, keeping the loudest side at the current level (as GNOME and Windows do).
function balanced(volumes, left, right, value) {
    const result = volumes.slice(), b = Math.max(-1, Math.min(1, value))
    const top = Math.max.apply(null, volumes.length ? volumes : [0])
    for (const i of left) result[i] = top * (1 - Math.max(0, b))
    for (const i of right) result[i] = top * (1 + Math.min(0, b))
    return result
}

function balanceLabel(value) {
    if (value === null || value === undefined) return "지원 안 함"
    const percent = Math.round(Math.abs(value) * 100)
    return percent === 0 ? "가운데" : (value < 0 ? "왼쪽 " : "오른쪽 ") + percent + "%"
}

// Playback streams grouped per application: one row per program, however many streams it opens.
// `targets` maps a stream id to the output node it is linked to (absent while not linked yet).
function applications(streams, targets) {
    const groups = []
    for (const stream of streams || []) {
        const binary = Devices.property(stream, "application.process.binary")
        const appName = Devices.property(stream, "application.name")
        const key = binary || appName || String(stream.name || stream.id)
        let group = groups.find(item => item.key === key)
        if (!group) {
            group = {key: key, name: appName || stream.description || binary || stream.name || "알 수 없는 앱",
                icon: Devices.property(stream, "application.icon-name") || binary.toLowerCase(), streams: []}
            groups.push(group)
        }
        group.streams.push(stream)
    }
    for (const group of groups) {
        const ready = group.streams.filter(stream => stream.audio)
        group.volume = ready.length ? Math.max.apply(null, ready.map(stream => stream.audio.volume)) : 0
        group.muted = ready.length > 0 && ready.every(stream => stream.audio.muted)
        group.available = ready.length > 0
        const linked = group.streams.map(stream => targets[stream.id] || null)
        group.target = linked.every(node => node && linked[0] && node.id === linked[0].id) ? linked[0] : null
        group.mixed = !group.target && linked.some(node => node)
        group.detail = group.streams.length > 1 ? "스트림 " + group.streams.length + "개" : (Devices.property(group.streams[0], "media.name") || "")
    }
    return groups.sort((a, b) => a.name.localeCompare(b.name))
}

// Peak amplitude (0..1) to lit bars on a -60..0 dB scale, so speech fills the meter and silence leaves it dark.
function meter(peak, bars) {
    if (!isFinite(peak) || peak <= 0) return 0
    const db = 20 * Math.log(peak) / Math.LN10
    return Math.max(0, Math.min(bars, Math.round((db + 60) / 60 * bars)))
}

function errorText(code) {
    const text = {
        InvalidArguments: "잘못된 장치 요청입니다.",
        StreamNotFound: "앱의 오디오 스트림이 이미 종료되었습니다.",
        TargetNotFound: "선택한 출력 장치가 연결 해제되었습니다.",
        MetadataFailed: "출력 장치를 바꾸지 못했습니다. WirePlumber 상태를 확인하세요.",
        PipeWireUnavailable: "PipeWire에 연결하지 못했습니다.",
        ToolMissing: "pw-metadata·pw-dump를 찾을 수 없습니다. pipewire 패키지를 확인하세요.",
        Timeout: "오디오 시스템이 응답하지 않습니다."
    }
    return text[String(code).trim()] || "출력 장치를 바꾸지 못했습니다."
}
