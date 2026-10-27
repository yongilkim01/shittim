import QtQuick
import "../../ui"

Item {
    id: root
    required property var audio
    required property var network
    required property var battery
    required property var bluetooth
    required property var brightness
    required property var capture
    property var notifications: null
    signal navigate(string page)
    readonly property real tileWidth: 93 + (width - Theme.controlPanelWidth) / 3
    implicitWidth: 337
    implicitHeight: 293
    // Panel 5 measured from the supplied 1536 x 1024 reference.
    // Previous layout rule:
    // Preserve all three columns by scaling the measured layout as a unit.
    // Preserve the three columns by resizing tracks; text and input targets keep logical sizes.
    Item {
        width: root.width; height: 293
        QuickTile {
            x: 18; y: 14; width: root.tileWidth; height: 70; large: true; title: "Wi-Fi"; glyph: "\uf1eb"
            active: root.network.wifiConnected
            detail: active ? root.network.ssid : root.network.wifiEnabled ? "On" : "Off"
            interactive: root.network.wifiDevices.length > 0
            hint: "클릭: Wi-Fi 관리 · 우클릭: Wi-Fi 켜기/끄기"
            onClicked: root.navigate("wifi"); onDetailsRequested: root.network.toggleWifi()
        }
        QuickTile {
            x: 18 + root.tileWidth + 13; y: 14; width: root.tileWidth-1; height: 70; large: true; title: "Bluetooth"; glyph: "\uf294"; glyphDisc: false
            active: root.bluetooth.adapter !== null && root.bluetooth.adapter.enabled
            detail: root.bluetooth.adapter === null ? "N/A" : active ? "On" : "Off"
            interactive: root.bluetooth.adapter !== null
            hint: "클릭: Bluetooth 관리 · 우클릭: 전원 켜기/끄기"
            onClicked: root.navigate("bluetooth"); onDetailsRequested: root.bluetooth.toggleBluetooth()
        }
        QuickTile {
            x: 18 + (root.tileWidth + 13) * 2; y: 14; width: root.tileWidth-1; height: 70; large: true; title: "Night Light"; glyph: "󰖙"
            detail: "N/A"; interactive: false; hint: "Night Light 제어는 아직 지원하지 않습니다."
        }
        Rectangle { x: 18; y: 94; width: root.width - 33; height: 1; color: Theme.border; opacity: 0.45 }
        HudIcon { x: 24; y: 103; width: 18; height: 20; font.pixelSize: 22; text: root.audio.muted ? "󰝟" : "\uf028"; color: root.audio.muted ? Theme.danger : Theme.accentBright }
        MouseArea { x: 22; y: 101; width: 24; height: 24; enabled: root.audio.available; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: event => { if (event.button === Qt.RightButton) root.navigate("audio"); else root.audio.toggleMute() } }
        HudSlider {
            id: volume; objectName: "overviewVolume"; x: 51; y: 102; width: root.width - 120; height: Theme.minimumTarget; padding: 0; implicitHeight: Theme.minimumTarget; trackHeight: 6
            enabled: root.audio.validVolume
            Binding { target: volume; property: "value"; value: root.audio.available ? Math.max(0, Math.min(1, root.audio.sink.audio.volume)) : 0; when: !volume.pressed; restoreMode: Binding.RestoreNone }
            onMoved: root.audio.setVolume(value)
        }
        HudText { x: root.width - 54; y: 103; width: 32; height: 20; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.accentBright; text: root.audio.available ? Math.round(volume.value * 100) + "%" : "N/A" }
        HudIcon { x: 24; y: 137; width: 18; height: 20; font.pixelSize: 22; text: "󰖙"; color: Theme.accentBright }
        MouseArea { x: 22; y: 135; width: 24; height: 24; onClicked: root.navigate("brightness") }
        HudSlider {
			id: brightness; objectName: "overviewBrightness"; x: 51; y: 136; width: root.width - 120; height: Theme.minimumTarget; padding: 0; implicitHeight: Theme.minimumTarget; trackHeight: 6
			enabled: root.brightness.backlight !== null && root.brightness.backlight.writable && root.brightness.ready
            Binding { target: brightness; property: "value"; value: root.brightness.backlight !== null ? root.brightness.backlight.value : 0; when: !brightness.pressed; restoreMode: Binding.RestoreNone }
            onMoved: if (!pressed) root.brightness.setBrightness(value)
            onPressedChanged: if (!pressed) root.brightness.setBrightness(value)
        }
        HudText { x: root.width - 54; y: 137; width: 32; height: 20; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.accentBright; text: root.brightness.backlight !== null ? Math.round(brightness.value * 100) + "%" : "N/A" }
        Rectangle { x: 18; y: 163; width: root.width - 33; height: 1; color: Theme.border; opacity: 0.45 }
        Repeater {
            model: [
                {name: "Screen Cast", key: "cast", icon: "󰍹", hint: "화면 공유 제어는 아직 지원하지 않습니다."},
                {name: "Do Not Disturb", key: "dnd", icon: "\uf186", hint: "방해 금지 전환 · 긴급 알림은 표시합니다."},
                {name: "Dark Mode", key: "dark", icon: "\uf042", hint: "고정 HUD 테마이며 시스템 테마 전환은 지원하지 않습니다."},
                {name: "Power", key: "power", icon: "\uf011", hint: "배터리와 전원 프로필"},
                {name: "Screenshot", key: "screenshot", icon: "󰆟", hint: "패널을 닫고 화면을 저장합니다."},
                {name: "Settings", key: "settings", icon: "󰢻", hint: "세부 설정"}
            ]
            QuickTile {
                required property var modelData
                required property int index
                objectName: "quick-" + modelData.key
                x: 18 + (index % 3) * (root.tileWidth + 13); y: 173 + Math.floor(index / 3) * 59
                width: root.tileWidth-(index%3===0 ? 0 : 1); height: 49
                title: modelData.name; glyph: modelData.icon
                hint: modelData.key === "dnd" && root.notifications !== null && !root.notifications.available ? "Shittim 알림 서버 소유권을 확인하세요." : modelData.hint
                active: modelData.key === "dnd" && root.notifications !== null && root.notifications.dnd
                interactive: ["power", "settings"].indexOf(modelData.key) >= 0 || modelData.key === "screenshot" && root.capture.screenshotAvailable || modelData.key === "dnd" && root.notifications !== null && root.notifications.available
                onClicked: { if (modelData.key === "dnd") root.notifications.toggleDnd(); else if (modelData.key === "screenshot") root.capture.takeScreenshot(); else root.navigate(modelData.key) }
            }
        }
    }
}
