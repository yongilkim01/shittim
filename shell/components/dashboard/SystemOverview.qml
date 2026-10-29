import QtQuick
import QtQuick.Controls.Basic as Controls
import "../../ui"
import "../control"
import "Format.js" as Format

Item {
    id: root
    required property var model
    readonly property var metrics: root.model ? root.model.snapshot : Format.emptySnapshot()
    readonly property string error: root.model && root.model.error || ""
    implicitWidth: 746; implicitHeight: 300
    // Main panel: header, then the gauges inside an inner frame split into four columns.
    HudFrame {
        x: 140; y: 8; width: 589; height: 151; level: "panel"
        HudSectionHeader { x: 14; y: 6; width: 561; height: 20; title: root.error || "시스템 개요"; color: root.error ? Theme.warning : Theme.accent }
        HudFrame {
            x: 10; y: 31; width: 569; height: 112; level: "control"
            cutTopLeft: 4; cutTopRight: 4; cutBottomRight: 4; cutBottomLeft: 4
            fillColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.5); strokeColor: Theme.frameLine
            Repeater {
                model: 3
                Item {
                    required property int index
                    x: (index + 1) * 142.25; y: 16; width: 1; height: 80
                    Rectangle { anchors.fill: parent; color: Theme.frameLine }
                    Rectangle { x: -3; y: parent.height / 2; width: 7; height: 1; color: Theme.border }
                }
            }
            Repeater {
                model: ["CPU", "RAM", "GPU", "TEMP"]
                DashboardGauge {
                    required property string modelData
                    required property int index
                    readonly property var measurement: index === 0 ? root.metrics.cpu : index === 1 ? root.metrics.memory : index === 2 ? root.metrics.gpu : root.metrics.temperature
                    objectName: "dashboardGauge-" + modelData
                    x: 8 + index * 142.25; y: 2
                    title: modelData
                    display: index === 3 ? Format.valid(measurement.value) ? Math.round(measurement.value) + "°C" : "N/A" : Format.percent(measurement.percent)
                    detail: index === 1 ? Format.bytes(measurement.used) + " / " + Format.bytes(measurement.total) : index === 3 ? measurement.label : measurement.name
                    value: index === 3 ? Format.valid(measurement.value) ? Math.max(0, Math.min(1, measurement.value / 100)) : -1 : Format.fraction(measurement.percent)
                    warning: index === 3 && Format.valid(measurement.critical) && measurement.value >= measurement.critical
                }
            }
        }
    }
    HudFrame {
        objectName: "dashboardStorage"; x: 140; y: 169; width: 326; height: 118; level: "card"
        HudSectionHeader { x: 14; y: 6; width: 298; height: 20; glyph: ""; title: "저장 공간" }
        ListView {
            id: storage; x: 14; y: 32; width: 298; height: 80; clip: true
            model: root.metrics.storage; boundsBehavior: Flickable.StopAtBounds
            Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded; width: 3; contentItem: Rectangle { implicitWidth: 3; color: Theme.accentDim } background: Item {} }
            delegate: Item {
                id: disk
                required property var modelData
                width: storage.width; height: 40
                HudIcon { x: 0; y: 1; width: 14; height: 16; text: ""; font.pixelSize: 11; color: Theme.textSecondary }
                HudText { x: 20; y: 0; width: 128; height: 17; text: disk.modelData.mount + " (" + disk.modelData.device.split('/').pop() + ")"; font.pixelSize: Theme.textCaption; color: Theme.textPrimary; elide: Text.ElideRight }
                HudText { x: 148; y: 0; width: 112; height: 17; horizontalAlignment: Text.AlignRight; text: Format.bytes(disk.modelData.used) + " / " + Format.bytes(disk.modelData.total); font.pixelSize: Theme.textCaption; color: Theme.textSecondary }
                HudText { x: 262; y: 0; width: 34; height: 17; horizontalAlignment: Text.AlignRight; text: Format.percent(disk.modelData.percent); font.pixelSize: Theme.textCaption; color: Theme.accentBright }
                HudProgress { x: 20; y: 23; width: 276; height: 5; value: Math.max(0, Format.fraction(disk.modelData.percent)) }
                MouseArea { id: mountHover; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                HudToolTip { visible: mountHover.containsMouse; text: disk.modelData.mount + " · " + disk.modelData.device + " · " + disk.modelData.filesystem }
            }
        }
        HudText { x: 14; y: 38; width: 290; height: 40; visible: root.metrics.storage.length === 0; text: root.metrics.storageReady ? "N/A" : "…"; font.pixelSize: 10; color: Theme.textMuted }
    }
    HudFrame {
        objectName: "dashboardNetwork"; x: 480; y: 169; width: 249; height: 118; level: "card"
        HudSectionHeader { x: 14; y: 6; width: 221; height: 20; glyph: ""; title: "네트워크"; detail: root.metrics.network.interface || "N/A" }
        NetworkGraph { objectName: "dashboardNetworkGraph"; x: 14; y: 32; width: 221; height: 50; samples: root.model ? root.model.samples : [] }
        Rectangle { x: 124; y: 88; width: 1; height: 24; color: Theme.frameLine }
        Column {
            x: 14; y: 86; width: 104; spacing: 0
            HudText { text: "↓ " + Format.rate(root.metrics.network.down); font.pixelSize: Theme.textStatus; color: Theme.accentBright }
            HudText { text: "다운로드"; font.pixelSize: 9; color: Theme.textMuted }
        }
        Column {
            x: 134; y: 86; width: 104; spacing: 0
            HudText { text: "↑ " + Format.rate(root.metrics.network.up); font.pixelSize: Theme.textStatus; color: Theme.accentBright }
            HudText { text: "업로드"; font.pixelSize: 9; color: Theme.textMuted }
        }
    }
}
