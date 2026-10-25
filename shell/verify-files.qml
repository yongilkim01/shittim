import QtQuick
import Quickshell
import Quickshell.Io
import "./components/files"
import "./ui/AssetPaths.js" as Assets

// Load the real UI and read the real home folder without mapping a window or modifying files.
ShellRoot {
    id: root
    property bool listingReady: false
    property int loadedAssets: 0
    readonly property var assetNames: ["icons/Shittim-HUD/scalable/apps/utilities-terminal.svg", "icons/Shittim-HUD/scalable/apps/system-file-manager.svg", "icons/Shittim-HUD/scalable/apps/preferences-system.svg", "icons/Shittim-HUD/scalable/places/user-trash.svg", "icons/Shittim-HUD/scalable/places/user-home.svg", "icons/Shittim-HUD/scalable/places/folder-projects.svg", "wallpapers/shittim-lake.png"]
    function finishIfReady() {
        if (listingReady && loadedAssets === assetNames.length) {
            console.info("[Shittim] 실제 파일 창·내장 아이콘·배경·GIO 읽기 검사 통과")
            Qt.callLater(() => Qt.quit())
        }
    }
    Item {
        Repeater {
            model: root.assetNames
            delegate: Image {
                required property string modelData
                source: Assets.asset(Quickshell.shellDir, modelData)
                sourceSize.width: 32; sourceSize.height: 32
                onStatusChanged: {
                    if (status === Image.Ready) { root.loadedAssets++; root.finishIfReady() }
                    else if (status === Image.Error) { console.error("[Shittim] 내장 이미지 로딩 실패: " + modelData); Qt.exit(1) }
                }
            }
        }
    }
    FilesModel { id: filesModel }
    FilesWindow { visible: false; width: 440; height: 326; browserModel: filesModel }
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
                        root.listingReady = true; root.finishIfReady()
                    } else if (result.event === "error") { console.error("[Shittim] " + result.error); Qt.exit(1) }
                } catch (_) { console.error("[Shittim] 파일 응답 형식 오류"); Qt.exit(1) }
            }
        }
    }
    Timer { interval: 12000; running: true; onTriggered: { console.error("[Shittim] 파일 검사 시간 초과"); Qt.exit(1) } }
}
