import QtQuick
import "../../ui"

Item {
    id: root
    required property var audio
    required property var network
    required property var battery
    required property var system
    signal navigate(string page)
    readonly property real ratio: width / 337
    implicitWidth: 337
    implicitHeight: 293 * ratio
    // Panel 5 measured from the supplied 1536 x 1024 reference.
    // Preserve all three columns by scaling the measured layout as a unit.
    Item {
        width: 337; height: 293; scale: root.ratio; transformOrigin: Item.TopLeft
        QuickTile {
            x: 18; y: 14; width: 93; height: 70; large: true; title: "Wi-Fi"; glyph: "\uf1eb"
            active: root.network.wifiConnected
            detail: active ? root.network.ssid : root.network.wifiEnabled ? "On" : "Off"
            interactive: root.network.wifiDevices.length > 0
            hint: "클릭: Wi-Fi 관리 · 우클릭: Wi-Fi 켜기/끄기"
            onClicked: root.navigate("wifi"); onDetailsRequested: root.network.toggleWifi()
        }
        QuickTile {
            x: 124; y: 14; width: 92; height: 70; large: true; title: "Bluetooth"; glyph: "\uf294"; glyphDisc: false
            active: root.system.adapter !== null && root.system.adapter.enabled
            detail: root.system.adapter === null ? "N/A" : active ? "On" : "Off"
            interactive: root.system.adapter !== null
            hint: "클릭: Bluetooth 관리 · 우클릭: 전원 켜기/끄기"
            onClicked: root.navigate("bluetooth"); onDetailsRequested: root.system.toggleBluetooth()
        }
        QuickTile {
            x: 230; y: 14; width: 92; height: 70; large: true; title: "Night Light"; glyph: "󰖙"
            detail: "N/A"; interactive: false; hint: "Night Light 제어는 아직 지원하지 않습니다."
        }
        Rectangle { x: 18; y: 94; width: 304; height: 1; color: Theme.border; opacity: 0.45 }
        HudIcon { x: 24; y: 103; width: 18; height: 20; font.pixelSize: 22; text: root.audio.muted ? "󰝟" : "\uf028"; color: root.audio.muted ? Theme.danger : Theme.accentBright }
        MouseArea { x: 22; y: 101; width: 24; height: 24; enabled: root.audio.available; acceptedButtons: Qt.LeftButton | Qt.RightButton; onClicked: event => { if (event.button === Qt.RightButton) root.navigate("audio"); else root.audio.toggleMute() } }
        HudSlider {
            id: volume; objectName: "overviewVolume"; x: 51; y: 102; width: 217; height: 20; padding: 0; implicitHeight: 20; trackHeight: 6
            enabled: root.audio.validVolume
            Binding { target: volume; property: "value"; value: root.audio.available ? Math.max(0, Math.min(1, root.audio.sink.audio.volume)) : 0; when: !volume.pressed; restoreMode: Binding.RestoreNone }
            onMoved: root.audio.setVolume(value)
        }
        HudText { x: 283; y: 103; width: 32; height: 20; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.accentBright; text: root.audio.available ? Math.round(volume.value * 100) + "%" : "N/A" }
        HudIcon { x: 24; y: 137; width: 18; height: 20; font.pixelSize: 22; text: "󰖙"; color: Theme.accentBright }
        MouseArea { x: 22; y: 135; width: 24; height: 24; onClicked: root.navigate("brightness") }
        HudSlider {
			id: brightness; objectName: "overviewBrightness"; x: 51; y: 136; width: 217; height: 20; padding: 0; implicitHeight: 20; trackHeight: 6
			enabled: root.system.backlight !== null && root.system.backlight.writable && root.system.ready
            Binding { target: brightness; property: "value"; value: root.system.backlight !== null ? root.system.backlight.value : 0; when: !brightness.pressed; restoreMode: Binding.RestoreNone }
            onMoved: if (!pressed) root.system.setBrightness(value)
            onPressedChanged: if (!pressed) root.system.setBrightness(value)
        }
        HudText { x: 283; y: 137; width: 32; height: 20; horizontalAlignment: Text.AlignRight; font.pixelSize: 10; color: Theme.accentBright; text: root.system.backlight !== null ? Math.round(brightness.value * 100) + "%" : "N/A" }
        Rectangle { x: 18; y: 163; width: 304; height: 1; color: Theme.border; opacity: 0.45 }
        Repeater {
            model: [
                {name: "Screen Cast", key: "cast", icon: "󰍹", hint: "화면 공유 제어는 아직 지원하지 않습니다."},
                {name: "Do Not Disturb", key: "dnd", icon: "\uf186", hint: "알림 센터가 없어 방해 금지 전환은 지원하지 않습니다."},
                {name: "Dark Mode", key: "dark", icon: "\uf042", hint: "고정 HUD 테마이며 시스템 테마 전환은 지원하지 않습니다."},
                {name: "Power", key: "power", icon: "\uf011", hint: "배터리와 전원 프로필"},
                {name: "Screenshot", key: "screenshot", icon: "󰆟", hint: "패널을 닫고 화면을 저장합니다."},
                {name: "Settings", key: "settings", icon: "󰢻", hint: "세부 설정"}
            ]
            QuickTile {
                required property var modelData
                required property int index
                objectName: "quick-" + modelData.key
                x: 18 + (index % 3) * 106; y: 173 + Math.floor(index / 3) * 59
                width: index % 3 === 0 ? 93 : 92; height: 49
                title: modelData.name; glyph: modelData.icon; hint: modelData.hint
                interactive: ["power", "settings"].indexOf(modelData.key) >= 0 || modelData.key === "screenshot" && root.system.screenshotAvailable
                onClicked: { if (modelData.key === "screenshot") root.system.takeScreenshot(); else root.navigate(modelData.key) }
            }
        }
    }
}
