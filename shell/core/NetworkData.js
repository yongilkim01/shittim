.pragma library

// Network settings: labels, input validation and diagnosis wording. Inputs are the JSON objects that
// scripts/network-service.py emits (or plain fixtures with the same fields); no Quickshell types here.

function parseIPv4(text) {
    const parts = String(text || "").trim().split(".")
    if (parts.length !== 4) return null
    const bytes = []
    for (const part of parts) {
        if (!/^(0|[1-9][0-9]{0,2})$/.test(part) || Number(part) > 255) return null
        bytes.push(Number(part))
    }
    return bytes
}

// Eight 16-bit groups, or null. Accepts "::" compression and an embedded IPv4 tail.
function parseIPv6(text) {
    let value = String(text || "").trim().toLowerCase()
    if (!value || value.indexOf("%") >= 0 || (value.match(/::/g) || []).length > 1) return null
    let tail = null
    if (value.indexOf(".") >= 0) {
        // "::ffff:192.0.2.1": parse the dotted tail, keep two placeholder groups in its place.
        const cut = value.lastIndexOf(":")
        const v4 = parseIPv4(value.slice(cut + 1))
        if (v4 === null) return null
        tail = [v4[0] * 256 + v4[1], v4[2] * 256 + v4[3]]
        value = value.slice(0, cut + 1) + "0:0"
    }
    const halves = value.split("::")
    const groups = half => half === "" ? [] : half.split(":")
    const head = groups(halves[0]), back = halves.length > 1 ? groups(halves[1]) : []
    for (const group of head.concat(back)) if (!/^[0-9a-f]{1,4}$/.test(group)) return null
    if (halves.length === 1 && head.length !== 8) return null
    if (halves.length === 2 && head.length + back.length > 7) return null
    const fill = halves.length === 2 ? new Array(8 - head.length - back.length).fill(0) : []
    const result = head.map(g => parseInt(g, 16)).concat(fill, back.map(g => parseInt(g, 16)))
    if (tail) { result[6] = tail[0]; result[7] = tail[1] }
    return result
}

function isIPv4(text) { return parseIPv4(text) !== null }
function isIPv6(text) { return parseIPv6(text) !== null }

function sameIPv4Network(a, b, prefix) {
    const x = parseIPv4(a), y = parseIPv4(b)
    if (!x || !y) return false
    for (let bit = 0; bit < prefix; bit++) {
        const i = Math.floor(bit / 8), mask = 0x80 >> (bit % 8)
        if ((x[i] & mask) !== (y[i] & mask)) return false
    }
    return true
}

function splitList(text) {
    return String(text || "").split(/[\s,;]+/).map(item => item.trim()).filter(item => item.length > 0)
}

// The editor form (strings from text fields) -> {ok, errors: {field: message}, request}. The adapter checks again.
function validate(form) {
    const errors = {}
    const request = {}
    for (const family of [4, 6]) {
        const key = "ipv" + family
        const method = form[key + "Method"]
        const parse = family === 4 ? isIPv4 : isIPv6
        const settings = {method: method, dns: [], autoDns: form[key + "AutoDns"] !== false}
        const dns = splitList(form[key + "Dns"])
        if (method !== "disabled" && method !== "ignore") {
            if (dns.length > 4) errors[key + "Dns"] = "DNS 서버는 4개까지 입력할 수 있습니다."
            else if (dns.some(item => !parse(item))) errors[key + "Dns"] = "IPv" + family + " DNS 주소 형식이 올바르지 않습니다."
            settings.dns = dns
            if (!settings.autoDns && dns.length === 0 && method !== "manual") errors[key + "Dns"] = "사용자 지정 DNS를 하나 이상 입력하세요."
        }
        if (method === "manual") {
            const prefix = Number(form[key + "Prefix"])
            const address = String(form[key + "Address"] || "").trim()
            const gateway = String(form[key + "Gateway"] || "").trim()
            if (!parse(address)) errors[key + "Address"] = "IPv" + family + " 주소 형식이 올바르지 않습니다."
            else if (family === 4 && (address.startsWith("127.") || address === "0.0.0.0" || Number(address.split(".")[0]) >= 224)) errors[key + "Address"] = "이 주소는 장치에 쓸 수 없습니다."
            if (!/^[0-9]{1,3}$/.test(String(form[key + "Prefix"]).trim()) || prefix < 1 || prefix > (family === 4 ? 32 : 128))
                errors[key + "Prefix"] = "프리픽스는 1–" + (family === 4 ? 32 : 128) + " 사이 숫자입니다."
            if (gateway) {
                if (!parse(gateway)) errors[key + "Gateway"] = "게이트웨이 형식이 올바르지 않습니다."
                else if (gateway === address) errors[key + "Gateway"] = "게이트웨이는 장치 주소와 달라야 합니다."
                else if (family === 4 && !errors[key + "Address"] && !errors[key + "Prefix"] && !sameIPv4Network(address, gateway, prefix))
                    errors[key + "Gateway"] = "게이트웨이가 주소/프리픽스와 같은 네트워크에 있지 않습니다."
            }
            Object.assign(settings, {address: address, prefix: prefix, gateway: gateway, autoDns: false})
        }
        request[key] = settings
    }
    const proxy = form.proxyMethod === "auto" ? "auto" : "none"
    const pac = String(form.pacUrl || "").trim()
    if (proxy === "auto" && pac && !/^(https?:\/\/[^\s/]+|file:\/\/\/)\S*$/.test(pac)) errors.pacUrl = "PAC 주소는 http(s):// 또는 file:/// 로 시작해야 합니다."
    request.proxy = {method: proxy, pacUrl: proxy === "auto" ? pac : ""}
    return {ok: Object.keys(errors).length === 0, errors: errors, request: request}
}

// A saved profile -> editor form strings.
function formFor(profile) {
    const family = (settings, key) => {
        const first = settings && settings.addresses && settings.addresses.length ? settings.addresses[0] : null
        const result = {}
        result[key + "Method"] = settings ? settings.method : "auto"
        result[key + "Address"] = first ? first.address : ""
        result[key + "Prefix"] = first ? String(first.prefix) : (key === "ipv4" ? "24" : "64")
        result[key + "Gateway"] = settings ? settings.gateway || "" : ""
        result[key + "Dns"] = settings ? (settings.dns || []).join(", ") : ""
        result[key + "AutoDns"] = settings ? settings.autoDns !== false : true
        return result
    }
    return Object.assign(family(profile ? profile.ipv4 : null, "ipv4"), family(profile ? profile.ipv6 : null, "ipv6"),
        {proxyMethod: profile && profile.proxy ? profile.proxy.method : "none", pacUrl: profile && profile.proxy ? profile.proxy.pacUrl : ""})
}

function methodLabel(method, family) {
    return ({auto: family === 6 ? "자동" : "자동(DHCP)", dhcp: "DHCPv6만", manual: "수동", disabled: "사용 안 함", ignore: "무시", "link-local": "링크 로컬",
             shared: "공유"})[method] || method || "알 수 없음"
}

function securityLabel(code) {
    return ({open: "개방(암호 없음)", wep: "WEP", "wpa-psk": "WPA-Personal", "wpa2-psk": "WPA2-Personal", sae: "WPA3-Personal",
             owe: "개방(OWE 암호화)", "wpa-eap": "기업용 802.1X", none: "개방(암호 없음)", "wpa-psk-profile": "WPA/WPA2-Personal"})[code] || "알 수 없음"
}

function profileSecurity(profile) {
    if (!profile || profile.type !== "wifi") return ""
    if (profile.eap || profile.keyMgmt === "wpa-eap") return securityLabel("wpa-eap")
    return ({"wpa-psk": "WPA/WPA2-Personal", sae: "WPA3-Personal", owe: securityLabel("owe"), none: securityLabel("open"), ieee8021x: "WEP"})[profile.keyMgmt] || profile.keyMgmt
}

function signalLabel(percent) {
    if (typeof percent !== "number" || !isFinite(percent)) return "알 수 없음"
    return percent >= 75 ? "매우 좋음" : percent >= 50 ? "좋음" : percent >= 25 ? "보통" : "약함"
}

function signalGlyph(percent) {
    return percent >= 75 ? "󰤨" : percent >= 50 ? "󰤥" : percent >= 25 ? "󰤢" : "󰤟"
}

// Access points of one SSID on one device: strongest first, bands present, how many radios answer.
function accessPoints(device, ssid) {
    if (!device || !device.accessPoints) return {count: 0, bands: [], strongest: null}
    const matching = device.accessPoints.filter(ap => ap.ssid === ssid).sort((a, b) => b.strength - a.strength)
    const bands = []
    for (const ap of matching) if (ap.band && bands.indexOf(ap.band) < 0) bands.push(ap.band)
    bands.sort()
    return {count: matching.length, bands: bands, strongest: matching.length ? matching[0] : null}
}

function deviceStateText(device) {
    if (!device) return "장치 없음"
    const state = device.state
    if (state <= 10) return "관리 안 함"
    if (state === 20) return device.type === "wired" ? "케이블 연결 안 됨" : "사용할 수 없음"
    if (state === 30) return "연결 안 됨"
    if (state === 60) return "인증 필요"
    if (state > 30 && state < 100) return "연결 중"
    if (state === 100) return "연결됨"
    if (state === 110) return "연결 해제 중"
    if (state === 120) return "연결 실패"
    return "알 수 없음"
}

function connectivityText(code) {
    return ({full: "인터넷에 연결됨", limited: "인터넷 연결 제한", portal: "로그인 필요(포털)", none: "인터넷 연결 없음", unknown: "확인 안 됨"})[code] || "확인 안 됨"
}

function connectivityColorKey(code) {
    return code === "full" ? "success" : code === "limited" || code === "portal" ? "warning" : code === "none" ? "danger" : "muted"
}

function speedText(mbps) {
    if (typeof mbps !== "number" || mbps <= 0) return "알 수 없음"
    return mbps >= 1000 ? (mbps / 1000) + " Gb/s" : mbps + " Mb/s"
}

function addressText(list) {
    return (list || []).filter(item => item && item.address && item.address.indexOf("fe80:") !== 0)
        .map(item => item.address + "/" + item.prefix).join(", ")
}

function qualityText(code) {
    return ({good: "우수", fair: "보통", poor: "나쁨", unknown: "판단 불가"})[code] || "진단 전"
}

// Wording for one finished or running diagnosis step: {state: ok|warn|fail|wait|skip, text}.
function diagnosisStep(report, key) {
    if (!report || !report.steps || !report.steps[key]) return {state: report && report.running ? "wait" : "none", text: report && report.running ? "확인 중…" : "—"}
    // Short enough for one row; the targets are named in the page's note and in `target`.
    const step = report.steps[key]
    if (key === "gateway") {
        if (!step.target) return {state: "skip", text: "게이트웨이 없음"}
        if (!step.result) return {state: "fail", text: "측정 실패(ping 사용 불가)"}
        if (step.result.received === 0) return {state: "fail", text: "응답 없음"}
        return {state: step.result.loss > 0 ? "warn" : "ok", text: step.result.latency + " ms · 손실 " + step.result.loss + "%"}
    }
    if (key === "dns") {
        if (step.skipped) return {state: "skip", text: "확인 대상이 IP라 생략"}
        if (!step.servers || step.servers.length === 0) return {state: "fail", text: "DNS 서버 없음"}
        const good = step.servers.filter(item => item.ok)
        const fastest = good.map(item => item.latency).filter(value => typeof value === "number").sort((a, b) => a - b)[0]
        return {state: good.length === step.servers.length ? "ok" : good.length ? "warn" : "fail",
                text: good.length + "/" + step.servers.length + " 응답" + (fastest !== undefined ? " · " + fastest + " ms" : "")}
    }
    const result = step.result
    const head = ({full: "정상", limited: "제한", portal: "로그인 필요", none: "연결 없음"})[step.connectivity] || "확인 안 됨"
    if (!result || result.received === 0) return {state: step.connectivity === "full" ? "warn" : "fail", text: head + " · ping 응답 없음"}
    return {state: step.connectivity === "full" && result.loss === 0 ? "ok" : "warn",
            text: head + " · " + result.latency + " ms · 손실 " + result.loss + "%"}
}

function errorText(code) {
    return ({
        InvalidAddress: "IP 주소가 올바르지 않습니다.", InvalidPrefix: "프리픽스가 올바르지 않습니다.",
        InvalidGateway: "게이트웨이가 올바르지 않습니다.", GatewayOutsideNetwork: "게이트웨이가 주소와 같은 네트워크에 있지 않습니다.",
        InvalidDns: "DNS 주소가 올바르지 않습니다.", InvalidMethod: "지원하지 않는 IP 설정 방식입니다.", InvalidProxy: "프록시 설정이 올바르지 않습니다.",
        InvalidPassword: "비밀번호는 8–63자(또는 16진수 64자)여야 합니다.", InvalidSettings: "설정 값이 올바르지 않습니다.",
        InvalidConnection: "연결 프로필을 찾지 못했습니다.", UnknownConnection: "연결 프로필을 찾지 못했습니다. 이미 삭제되었을 수 있습니다.",
        InvalidDevice: "네트워크 장치를 찾지 못했습니다.", UnknownDevice: "네트워크 장치를 찾지 못했습니다.",
        ConfirmPending: "이전 변경의 유지 여부를 먼저 선택하세요.", NothingToConfirm: "확인할 변경 사항이 없습니다. 이미 복원되었을 수 있습니다.",
        DiagnosisRunning: "진단이 이미 실행 중입니다.", PermissionDenied: "권한이 없거나 관리자 인증이 취소되었습니다.",
        NotAuthorized: "권한이 없거나 관리자 인증이 취소되었습니다.", AccessDenied: "권한이 없거나 관리자 인증이 취소되었습니다.",
        NotActive: "이미 연결되어 있지 않습니다.", ConnectionActivating: "이미 연결하는 중입니다.",
        Timeout: "NetworkManager 응답 시간이 지났습니다. 현재 상태를 확인하세요.", BusUnavailable: "NetworkManager에 연결하지 못했습니다.",
        DBusDependencyUnavailable: "NetworkManager에 연결하지 못했습니다. python-dbus-next 설치와 NetworkManager 서비스를 확인하세요.",
        InvalidArguments: "NetworkManager가 이 설정을 거부했습니다. 값을 확인하세요.", Failed: "NetworkManager가 요청을 처리하지 못했습니다.",
        BackendUnavailable: "네트워크 설정 서비스에 연결하지 못했습니다.", BackendExited: "네트워크 설정 서비스가 종료되었습니다. 화면을 다시 여세요.",
        RequestTimeout: "요청 응답 시간이 지났습니다. 실제 상태를 확인한 뒤 다시 시도하세요.", QueueFull: "처리할 요청이 많습니다. 잠시 후 다시 시도하세요."
    })[code] || "요청을 완료하지 못했습니다. 상태를 확인하고 다시 시도하세요."
}
