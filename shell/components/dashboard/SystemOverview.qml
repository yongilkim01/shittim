import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"
import "Format.js" as Format

Item {
    id: root
    required property var model
    readonly property var metrics: root.model ? root.model.snapshot : Format.emptySnapshot()
    implicitWidth: 746; implicitHeight: 300
    HudText { x: 150; y: 15; width: 570; height: 18; text: root.model && root.model.error || "SYSTEM OVERVIEW"; font.pixelSize: 10; font.letterSpacing: 1; color: root.model && root.model.error ? Theme.warning : Theme.accent }
    ControlFrame {
        x: 140; y: 36; width: 589; height: 122; cut: 4
        strokeColor: Theme.border; fillColor: Theme.background
        Repeater {
            model: ["CPU", "RAM", "GPU", "TEMP"]
            DashboardGauge {
                required property string modelData
                required property int index
                readonly property var measurement: index === 0 ? root.metrics.cpu : index === 1 ? root.metrics.memory : index === 2 ? root.metrics.gpu : root.metrics.temperature
                objectName: "dashboardGauge-" + modelData
                x: 10 + index * 137.5; y: 10
                title: modelData
                display: index === 3 ? Format.valid(measurement.value) ? Math.round(measurement.value) + "°C" : "N/A" : Format.percent(measurement.percent)
                detail: index === 1 ? Format.bytes(measurement.used) + " / " + Format.bytes(measurement.total) : index === 3 ? measurement.label : measurement.name
                value: index === 3 ? Format.valid(measurement.value) ? Math.max(0, Math.min(1, measurement.value / 100)) : -1 : Format.fraction(measurement.percent)
                warning: index === 3 && Format.valid(measurement.critical) && measurement.value >= measurement.critical
            }
        }
    }
    ControlFrame {
        objectName: "dashboardStorage"; x: 140; y: 169; width: 326; height: 118; cut: 4
        HudText { x: 18; y: 8; width: 285; height: 20; text: "STORAGE"; font.pixelSize: 10; font.letterSpacing: 1; color: Theme.accent }
        ListView {
            id: storage; x: 18; y: 31; width: 290; height: 80; clip: true
            model: root.metrics.storage; boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3 }
            delegate: Item {
                id: disk
                required property var modelData
                width: storage.width; height: 40
                HudText { x: 0; y: 0; width: 137; height: 17; text: disk.modelData.mount + " (" + disk.modelData.device.split('/').pop() + ")"; font.pixelSize: 9; color: Theme.textPrimary }
                HudText { x: 138; y: 0; width: 151; height: 17; horizontalAlignment: Text.AlignRight; text: Format.bytes(disk.modelData.used) + " / " + Format.bytes(disk.modelData.total); font.pixelSize: 9; color: Theme.textSecondary }
                Rectangle {
                    x: 0; y: 23; width: 253; height: 6; color: Theme.surfaceElevated; radius: 1
                    Rectangle { width: parent.width * Math.max(0, Format.fraction(disk.modelData.percent)); height: parent.height; color: Theme.accent; radius: 1 }
                }
                HudText { x: 260; y: 18; width: 30; height: 16; horizontalAlignment: Text.AlignRight; text: Format.percent(disk.modelData.percent); font.pixelSize: 9; color: Theme.accentBright }
                MouseArea { id: mountHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                Controls.ToolTip.visible: mountHover.containsMouse
                Controls.ToolTip.text: disk.modelData.mount + " · " + disk.modelData.device + " · " + disk.modelData.filesystem
            }
        }
        HudText { x: 18; y: 38; width: 290; height: 40; visible: root.metrics.storage.length === 0; text: root.metrics.storageReady ? "N/A" : "…"; font.pixelSize: 10; color: Theme.textMuted }
    }
    ControlFrame {
        objectName: "dashboardNetwork"; x: 480; y: 169; width: 249; height: 118; cut: 4
        HudText { x: 18; y: 8; width: 100; height: 20; text: "NETWORK"; font.pixelSize: 10; font.letterSpacing: 1; color: Theme.accent }
        HudText { x: 120; y: 8; width: 111; height: 20; horizontalAlignment: Text.AlignRight; text: root.metrics.network.interface || "N/A"; font.pixelSize: 9; color: Theme.textSecondary }
        NetworkGraph { objectName: "dashboardNetworkGraph"; x: 18; y: 36; width: 213; height: 48; samples: root.model ? root.model.samples : [] }
        HudText { x: 18; y: 91; width: 104; height: 18; text: "↓ " + Format.rate(root.metrics.network.down); font.pixelSize: 9; color: Theme.accentBright }
        HudText { x: 127; y: 91; width: 104; height: 18; text: "↑ " + Format.rate(root.metrics.network.up); font.pixelSize: 9; color: Theme.accentBright }
    }
}
