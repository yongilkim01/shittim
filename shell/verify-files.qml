import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "./components/files"

// Load the real UI and read the real home folder without mapping a window or modifying files.
ShellRoot {
    FilesModel { id: filesModel }
    Window { visible: false; width: 440; height: 326; FilesView { anchors.fill: parent; model: filesModel } }
    Process {
        id: backend; running: true; stdinEnabled: true
        command: ["python3", "-u", Quickshell.shellDir + "/../scripts/files-service.py"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    const result = JSON.parse(data)
                    filesModel.accept(result)
                    if (result.event === "ready") {
                        filesModel.open(result.home, false)
                        backend.write(JSON.stringify({ action: "browse", tab: filesModel.current.id, request: filesModel.current.request, uri: result.home }) + "\n")
                    } else if (result.event === "listing") {
                        console.info("[Shittim] 파일 관리자 UI·실제 GIO 폴더 읽기 검사 통과: " + result.entries.length + "개")
                        Qt.callLater(() => Qt.quit())
                    } else if (result.event === "error") { console.error("[Shittim] " + result.error); Qt.exit(1) }
                } catch (_) { console.error("[Shittim] 파일 응답 형식 오류"); Qt.exit(1) }
            }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("[Shittim] 파일 검사 시간 초과"); Qt.exit(1) } }
}
