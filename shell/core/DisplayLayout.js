.pragma library

// Monitor layout math and words for the display page. Pure functions: no Hyprland, no processes.
// Positions are Hyprland layout pixels (mode size / scale, swapped when rotated); scripts/display-config.py
// checks the same rules again before anything is applied.

const SCALES = [100, 125, 150, 160, 175, 200, 225, 250, 300]
const TRANSFORMS = [{value: 0, label: "가로"}, {value: 1, label: "세로"}, {value: 2, label: "가로 (반전)"}, {value: 3, label: "세로 (반전)"}]
const FIELDS = ["width", "height", "refresh", "scale", "transform", "x", "y"]

// Hyprland's own check: at n/120 the logical size must be whole pixels, otherwise it picks another scale.
function clean(width, height, scale) {
    const step = Math.round(scale * 120)
    if (step <= 0) return false
    const value = step / 120
    return Number.isInteger(width / value) && Number.isInteger(height / value)
}

function logical(item) {
    const width = Math.round(item.width / item.scale), height = Math.round(item.height / item.scale)
    return item.transform % 2 ? {width: height, height: width} : {width: width, height: height}
}

function rect(item) {
    const size = logical(item)
    return {x: item.x, y: item.y, width: size.width, height: size.height}
}

function overlap(a, b) {
    return Math.min(a.x + a.width, b.x + b.width) > Math.max(a.x, b.x) && Math.min(a.y + a.height, b.y + b.height) > Math.max(a.y, b.y)
}

function touching(a, b) {
    const side = (a.x + a.width === b.x || b.x + b.width === a.x) && Math.min(a.y + a.height, b.y + b.height) > Math.max(a.y, b.y)
    const stacked = (a.y + a.height === b.y || b.y + b.height === a.y) && Math.min(a.x + a.width, b.x + b.width) > Math.max(a.x, b.x)
    return side || stacked
}

// "" when the layout can be applied, otherwise what the user has to fix.
function problem(items) {
    const rects = items.map(rect)
    for (let i = 0; i < rects.length; ++i)
        for (let j = i + 1; j < rects.length; ++j)
            if (overlap(rects[i], rects[j])) return "화면이 서로 겹칩니다. 화면을 끌어 다른 화면 옆에 놓으세요."
    const reached = [0], queue = [0]
    while (queue.length && rects.length) {
        const current = queue.pop()
        for (let i = 0; i < rects.length; ++i)
            if (reached.indexOf(i) < 0 && touching(rects[current], rects[i])) { reached.push(i); queue.push(i) }
    }
    return rects.length && reached.length !== rects.length ? "모든 화면이 다른 화면과 한 변 이상 맞닿아야 마우스가 오갈 수 있습니다." : ""
}

function copy(items) { return items.map(item => Object.assign({}, item)) }

function same(a, b) {
    if (!a || !b) return false
    return a.name === b.name && FIELDS.every(key => typeof a[key] === "number" ? Math.abs(a[key] - b[key]) < 0.0001 : a[key] === b[key])
}

function sameLayout(first, second) {
    return first.length === second.length && first.every(item => same(item, second.find(other => other.name === item.name)))
}

function resolutions(modes) {
    const seen = {}, list = []
    for (const mode of modes) {
        const key = mode.width + "x" + mode.height
        if (!seen[key]) { seen[key] = true; list.push({width: mode.width, height: mode.height}) }
    }
    return list.sort((a, b) => b.width * b.height - a.width * a.height || b.width - a.width)
}

function refreshes(modes, width, height) {
    const list = []
    for (const mode of modes)
        if (mode.width === width && mode.height === height && list.indexOf(mode.refresh) < 0) list.push(mode.refresh)
    return list.sort((a, b) => b - a)
}

function closestRefresh(modes, width, height, wanted) {
    const list = refreshes(modes, width, height)
    if (!list.length) return wanted
    return list.reduce((best, value) => Math.abs(value - wanted) < Math.abs(best - wanted) ? value : best, list[0])
}

function scaleOptions(width, height, current) {
    const values = SCALES.map(percent => Math.round(percent * 1.2) / 120).filter(value => clean(width, height, value))
    if (current && clean(width, height, current) && !values.some(value => Math.abs(value - current) < 0.0001)) values.push(current)
    return values.sort((a, b) => a - b).map(value => ({value: value, label: scaleLabel(value)}))
}

function transformOptions(current) {
    // Flipped transforms are not offered; one set elsewhere stays selectable as it is.
    return current > 3 ? TRANSFORMS.concat([{value: current, label: "대칭 (현재 설정)"}]) : TRANSFORMS
}

function scaleLabel(value) { return Math.round(value * 1000) / 10 + "%" }
function refreshLabel(value) { return Math.round(value * 100) / 100 + " Hz" }
function resolutionLabel(width, height) { return width + " × " + height }
function transformLabel(value) { const found = transformOptions(value).find(option => option.value === value); return found ? found.label : String(value) }

function title(monitor) {
    if (!monitor) return ""
    if (monitor.internal) return "내장 디스플레이"
    const name = (monitor.make + " " + monitor.model).trim()
    return name || monitor.name
}

// After a monitor changes size, screens that sat to its right or below keep touching it.
function reflow(items, name, before) {
    const result = copy(items), changed = result.find(item => item.name === name)
    if (!changed) return result
    const old = rect(before), now = rect(changed)
    const dx = now.width - old.width, dy = now.height - old.height
    for (const item of result) {
        if (item.name === name) continue
        if (dx && item.x >= old.x + old.width) item.x += dx
        if (dy && item.y >= old.y + old.height) item.y += dy
    }
    return result
}

function clamp(value, low, high) { return Math.max(low, Math.min(high, value)) }

// Nearest free spot that shares an edge with another screen; edges closer than `pull` line up.
function snap(items, name, x, y) {
    const moving = items.find(item => item.name === name)
    if (!moving) return null
    const size = logical(moving), others = items.filter(item => item.name !== name).map(rect)
    if (!others.length) return {x: moving.x, y: moving.y}
    const pull = Math.max(size.width, size.height) * 0.06
    const align = (value, start, length, otherStart, otherLength) => {
        for (const target of [otherStart, otherStart + otherLength - length, otherStart + (otherLength - length) / 2])
            if (Math.abs(value - target) <= pull) return Math.round(target)
        return Math.round(clamp(value, otherStart - length + 1, otherStart + otherLength - 1))
    }
    const candidates = []
    for (const other of others) {
        const alongY = align(y, y, size.height, other.y, other.height), alongX = align(x, x, size.width, other.x, other.width)
        candidates.push({x: other.x + other.width, y: alongY}, {x: other.x - size.width, y: alongY},
                        {x: alongX, y: other.y + other.height}, {x: alongX, y: other.y - size.height})
    }
    let best = null, distance = Infinity
    for (const candidate of candidates) {
        const box = {x: candidate.x, y: candidate.y, width: size.width, height: size.height}
        if (others.some(other => overlap(box, other))) continue
        const d = Math.hypot(candidate.x - x, candidate.y - y)
        if (d < distance) { distance = d; best = candidate }
    }
    return best || {x: moving.x, y: moving.y}
}

// Keyboard placement: next to the other screens in a direction ("left", "right", "up", "down").
function place(items, name, direction) {
    const moving = items.find(item => item.name === name)
    const others = items.filter(item => item.name !== name).map(rect)
    if (!moving || !others.length) return null
    const size = logical(moving)
    const left = Math.min(...others.map(r => r.x)), top = Math.min(...others.map(r => r.y))
    const right = Math.max(...others.map(r => r.x + r.width)), bottom = Math.max(...others.map(r => r.y + r.height))
    const target = direction === "left" ? {x: left - size.width, y: top} : direction === "right" ? {x: right, y: top}
        : direction === "up" ? {x: left, y: top - size.height} : {x: left, y: bottom}
    return snap(items, name, target.x, target.y)
}

// Codes printed by scripts/display-config.py.
function errorText(code) {
    const text = String(code || "")
    if (text.indexOf("HyprlandRejected") === 0) return "Hyprland 가 이 설정을 거부했습니다."
    switch (text) {
    case "UnsupportedMode": return "이 모니터가 지원하지 않는 해상도·주사율입니다."
    case "InvalidScale": return "이 해상도에서 쓸 수 없는 배율입니다."
    case "InvalidTransform": return "지원하지 않는 화면 방향입니다."
    case "MonitorsOverlap": return "화면이 서로 겹칩니다."
    case "MonitorsSeparated": return "떨어져 있는 화면이 있습니다. 화면끼리 맞닿게 놓으세요."
    case "MonitorNotConnected": case "MonitorSetChanged": return "모니터 연결이 바뀌었습니다. 목록을 다시 읽었으니 다시 설정하세요."
    case "GuardUnavailable": return "자동 복구를 시작할 수 없어 설정을 바꾸지 않았습니다. (systemd 사용자 세션 필요)"
    case "ChangeRunning": return "앞선 변경을 확인하는 중입니다."
    case "HyprctlFailed": return "Hyprland 에 연결하지 못했습니다."
    case "NoChange": return "확인을 기다리는 변경이 없습니다."
    case "NoSnapshot": return "되돌릴 이전 설정 기록이 없습니다."
    default: return "디스플레이 설정을 처리하지 못했습니다." + (text ? " (" + text + ")" : "")
    }
}

// Final word on a change, from the guard's status file.
function outcomeText(status, linked) {
    if (!status || !status.state) return ""
    const via = status.method === "reload" ? " Hyprland 설정 파일을 다시 읽어 복원했습니다." : ""
    switch (status.state) {
    case "kept":
        if (status.error) return "화면에는 적용됐지만 저장하지 못했습니다. 다음 로그인 때는 이전 설정으로 시작합니다."
        return linked === false ? "변경 사항을 유지했습니다. 다음 로그인에도 쓰려면 ./install.sh 를 한 번 다시 실행하세요." : "변경 사항을 유지하고 저장했습니다."
    case "reverted":
        if (status.reason === "timeout") return "15초 안에 확인하지 않아 이전 설정으로 복원했습니다." + via
        if (status.reason === "disconnected") return "모니터 연결이 바뀌어 이전 설정으로 복원했습니다." + via
        if (status.reason === "user" || status.reason === "restore") return "이전 설정으로 복원했습니다." + via
        return "변경 확인이 중단되어 이전 설정으로 복원했습니다." + via
    case "failed": return "Hyprland 가 새 설정을 적용하지 못해 이전 설정으로 복원했습니다." + via
    case "restore-failed": return "이전 설정으로 복원하지 못했습니다. TTY(Ctrl+Alt+F3)에서 python3 ~/projects/shittim/scripts/display-config.py restore 를 실행하세요."
    default: return ""
    }
}
