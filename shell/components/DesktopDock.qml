import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../services"
import "../ui"
import "./dock"

PanelWindow {
    id: window
    required property var modelData
    screen: modelData
    readonly property bool expanded: DockState.screen === screen && DockState.mode !== ""
    readonly property var monitor: Hyprland.monitors.values.find(output => output.name === screen.name) || null
    readonly property bool fullscreen: WindowState.windows.some(client => client.monitor === (monitor ? monitor.id : -1) && (client.fullscreen & 2)!==0 && !client.hidden && client.workspace === (monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : ""))
    visible: !fullscreen
    anchors { bottom: true }
    margins.bottom: Theme.dockBottomMargin
    implicitWidth: Math.min(screen.width - 24, Math.max(224, Math.min(640, MediaState.apps.length * Theme.dockCellSize + Theme.dockEndSpace)))
    // Keep the layer surface fixed while previews open; only its input region changes.
    implicitHeight: Math.min(screen.height - Theme.barHeight - 24, Theme.dockHeight + 342)
    color: Theme.transparent
    // Reserve the strip only; opening menus or previews must not resize app windows.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.dockHeight
    WlrLayershell.namespace: "shittim-dock"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: expanded && DockState.mode !== "preview" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region {
        item: view.stripItem
        Region { item: view.popupItem; intersection: Intersection.Combine }
        Region { item: view.errorItem; intersection: Intersection.Combine }
    }
    HyprlandFocusGrab { active: window.visible && window.expanded && DockState.mode !== "preview"; windows: [window]; onCleared: DockState.close() }
    onVisibleChanged: if (!visible && DockState.screen===screen) DockState.close()
    Timer { id: hoverTimer; interval: 400; property var app: null; onTriggered: { if (app && MediaState.matches(app).length > 0 && ["menu","choose"].indexOf(DockState.mode) < 0) DockState.open(app,"preview",window.screen) } }
    Timer { id: leaveTimer; interval: 350; onTriggered: { if (DockState.mode === "preview") DockState.close() } }
    DockView {
        id: view; anchors.fill: parent; apps: DockState.apps; favorites: LauncherState.dockFavorites
        trashAvailable: DesktopState.ready && DesktopState.entries.some(entry => entry.id === "trash")
        matches: app => MediaState.matches(app); iconSource: LauncherState.iconSource
        mode: window.expanded ? DockState.mode : ""; app: DockState.app; windows: DockState.windows; target: DockState.target
        error:LauncherState.dockError || MediaState.error || LauncherState.error
        onAppClicked: app => { hoverTimer.stop(); DockState.click(app,window.screen) }
        onAppHovered: app => { hoverTimer.app=app; hoverTimer.restart() }
        onAppMenu: app => { hoverTimer.stop(); DockState.open(app,"menu",window.screen) }
        onActionRequested: operation => DockState.act(operation)
        onWindowChosen: address => { DockState.close(); WindowState.perform("activate",address) }
        onTargetChosen: address => DockState.targetAddress=address
        onReorderRequested: (appId,index) => LauncherState.dockAction("reorder",appId,index)
        onLauncherRequested: { DockState.close(); LauncherState.show() }
        onSettingsRequested: { DockState.close(); ControlState.toggle(window) }
        onTrashRequested: { DockState.close(); DesktopState.send("open", {ids:["trash"]}) }
        onCloseRequested: DockState.close()
        onHoverLeft: { hoverTimer.stop(); leaveTimer.restart() }
        onHoverEntered: leaveTimer.stop()
        previewContent: Component {
            Item {
                id:previewRoot
                readonly property var entry: parent.entry
                ScreencopyView {
                    id: copy; anchors.centerIn: parent
                    width: Math.min(parent.width, implicitWidth); height: Math.min(parent.height, implicitHeight)
                    constraintSize: Qt.size(parent.width,parent.height)
                    captureSource: previewRoot.entry && previewRoot.entry.handle ? previewRoot.entry.handle.wayland : null
                    live: window.visible && window.expanded && DockState.mode !== "menu" && previewRoot.entry && !previewRoot.entry.hidden
                }
                Image { anchors.centerIn: parent; width: 42; height: 42; source: DockState.app ? LauncherState.iconSource(DockState.app) : ""; visible: !copy.hasContent }
                HudText { anchors.bottom: parent.bottom; width: parent.width; text: !copy.hasContent ? "미리보기 사용 불가" : ""; horizontalAlignment: Text.AlignHCenter; font.pixelSize: 9; color: Theme.textMuted }
            }
        }
    }
}
