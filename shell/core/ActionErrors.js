.pragma library

function message(code) {
    const messages={
        RequestTimeout:"요청 응답 시간이 지났습니다. 실제 적용 상태를 확인한 뒤 다시 시도하세요.",
        BackendUnavailable:"서비스에 연결하지 못했습니다. 새로고침으로 다시 연결하세요.",
        BackendExited:"서비스가 종료되었습니다. 새로고침으로 다시 연결하세요.",
        InvalidResponse:"서비스 응답을 읽지 못했습니다. 새로고침으로 상태를 확인하세요.",
        QueueFull:"처리할 요청이 많습니다. 잠시 후 다시 시도하세요.",
        WindowClosed:"창이 닫혔습니다. 다른 창을 선택하세요.",
        OutcomeUnknown:"창 명령의 적용 여부를 확인하지 못했습니다. 현재 창 상태를 먼저 확인하세요.",
        CannotHideSpecialOrGroupedWindow:"고정·그룹·특수 워크스페이스 창은 숨기지 않습니다.",
        ExitFullscreenBeforeMaximize:"전체 화면을 해제한 뒤 최대화하세요.",
        CannotMaximizePinnedOrGroupedWindow:"고정·그룹 창은 먼저 고정 또는 그룹을 해제하세요.",
        InvalidRestoreGeometry:"복원 위치를 읽지 못했습니다. 현재 창은 유지합니다.",
        Cancelled:"요청이 취소되었습니다.",
        ProtectedShortcut:"기본 바로가기는 이동하거나 삭제할 수 없습니다.",
        DesktopDirectoryUnavailable:"XDG 바탕화면 폴더 설정을 확인하세요.",
        FileOperationBusy:"이전 파일 작업이 아직 실행 중입니다. 상태를 확인한 뒤 다시 시도하세요.",
        BrightnessPermissionDenied:"밝기 제어 권한이 없습니다. 세션 권한을 확인한 뒤 새로고침하세요.",
        BrightnessSessionUnavailable:"밝기를 조절할 현재 사용자의 활성 로컬 세션을 찾지 못했습니다.",
        BrightnessCommandFailed:"밝기 변경 명령이 실패했습니다. 장치 상태를 확인하고 다시 시도하세요.",
        BrightnessLogindFailed:"밝기 변경 명령이 실패했습니다. 장치 상태를 확인하고 다시 시도하세요.",
        BrightnessToolUnavailable:"brightnessctl이 없고 세션 밝기 제어도 사용할 수 없습니다.",
        BrightnessTimeout:"밝기 변경 응답 시간이 초과되었습니다.",
        DBusDependencyUnavailable:"D-Bus 보조 서비스를 시작하지 못했습니다. python-dbus-next 설치를 확인하세요.",
        AuthenticationRejected:"Bluetooth 인증이 거부되었습니다.",
        AuthenticationFailed:"Bluetooth 인증에 실패했습니다.",
        NotReady:"어댑터 전원 또는 하드웨어 차단 상태를 확인하세요.",
        TimeoutError:"요청 시간이 초과되었습니다. 장치 상태를 확인하세요.",
        ClipboardCopyFailed:"캡처는 저장했지만 클립보드 복사에 실패했습니다.",
        ScreenshotFailed:"스크린샷을 저장하지 못했습니다."
    }
    return messages[code] || "요청을 완료하지 못했습니다. 상태를 확인하고 다시 시도하세요."
}
