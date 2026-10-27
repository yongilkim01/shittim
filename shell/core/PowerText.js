.pragma library

// User-facing words for power.json values. Choices mirror CHOICES/LID in scripts/power-policy.py.
const CHOICES = {
    lock: [0, 1, 2, 3, 5, 10, 15, 30],
    screenOff: [0, 1, 2, 3, 5, 10, 15, 30, 60],
    suspend: [0, 10, 15, 20, 30, 45, 60, 120],
    lid: ["system", "suspend", "screen-off", "ignore"]
}
const LOGIND = {suspend: "절전", "suspend-then-hibernate": "절전 후 최대 절전", hibernate: "최대 절전", "hybrid-sleep": "하이브리드 절전",
    lock: "잠금", ignore: "아무것도 안 함", poweroff: "전원 끄기", halt: "시스템 정지", kexec: "커널 재시작"}

function duration(minutes) {
    if (!minutes) return "사용 안 함"
    return minutes % 60 === 0 ? minutes / 60 + "시간" : minutes + "분"
}

function lid(value, systemValue) {
    if (value === "system") return "시스템 설정" + (systemValue ? " (" + (LOGIND[systemValue] || systemValue) + ")" : "")
    return value === "suspend" ? "절전" : value === "screen-off" ? "잠그고 화면 끄기" : value === "ignore" ? "아무것도 안 함" : String(value)
}

function label(key, value, systemValue) {
    return key === "lid" ? lid(value, systemValue) : duration(value)
}

function options(key, systemValue) {
    return (CHOICES[key] || []).map(value => ({value: value, label: label(key, value, systemValue)}))
}

function sourceName(source) {
    return source === "battery" ? "배터리 사용 시" : "전원 연결 시"
}

// applyState comes from PowerPolicyState: what the idle service reports, not what the file says.
function status(applyState, source) {
    switch (applyState) {
    case "applied": return "변경 사항이 자동 저장되고 적용되었습니다 · 지금은 " + sourceName(source) + " 정책"
    case "pending": return "저장됨 · 적용 중…"
    case "external": return "다른 hypridle 이 실행 중이라 Shittim 정책을 적용하지 않았습니다."
    case "failed": return "hypridle 을 시작하지 못했습니다. bash scripts/verify-power.sh 로 확인하세요."
    case "lid": return "시간 설정은 적용됨 · 덮개 동작은 권한이 없어 시스템 설정을 따릅니다."
    case "invalid": return "설정 파일이 손상되어 기본값으로 동작 중입니다. 값을 바꾸면 새로 저장합니다."
    default: return "저장됨 · 자동 잠금 서비스가 꺼져 있어 아직 적용되지 않았습니다."
    }
}
