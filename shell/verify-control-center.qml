import QtQuick
import Quickshell
import Quickshell.Io
import "./components"
import "./services"

// Compile and instantiate the real 0.3.2 imports without mapping a second bar.
// Keep this entrypoint beside shell.qml: Quickshell confines imports to its config root.
ShellRoot {
	id: root
	property bool receivedReady: false
	property bool receivedState: false
	TopBar { visible: false }
	ControlCenter { visible: false }
	// Run the same helper path and parser as the panel without enabling any controls.
	Process {
		command: ["python3", "-u", SystemControl.helperPath]
		stdinEnabled: true
		running: true
		stdout: SplitParser {
			onRead: data => {
				try {
					const message = JSON.parse(data)
					SystemControl.receive(message)
					if (message.event === "ready") root.receivedReady = true
					if (message.event === "state" && root.receivedReady && Array.isArray(message.backlights)) {
						root.receivedState = true
						console.info("[Shittim] 시스템 보조 서비스 응답 확인. 백라이트 장치: " + message.backlights.length)
						Qt.callLater(() => Qt.quit())
					}
				} catch (_) {
					console.error("[Shittim] 시스템 보조 서비스 응답 형식 오류")
					Qt.exit(1)
				}
			}
		}
		// Do not copy raw helper output into the journal.
		stderr: SplitParser { onRead: data => console.error("[Shittim] 시스템 보조 서비스 실행 오류") }
		onExited: (code, status) => {
			if (!root.receivedState) {
				console.error("[Shittim] 시스템 정보를 받기 전에 보조 서비스가 종료됨: " + code)
				Qt.exit(1)
			}
		}
	}
	Timer {
		interval: 12000; running: true
		onTriggered: { console.error("[Shittim] 시스템 보조 서비스 응답 시간 초과"); Qt.exit(1) }
	}
}
