import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// All shell grabs share the session owner and close/release ordering.
Scope {
    id: root
    required property var window
    required property var session
    readonly property bool eligible: window.visible && session.active && session.keyboard
    readonly property bool active: grab.active
    readonly property int keyboardFocus: eligible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    HyprlandFocusGrab {
        id:grab
        active:root.eligible
        windows:root.session.anchorWindow ? [root.window,root.session.anchorWindow] : [root.window]
        onCleared:root.session.close("outside")
    }
    Shortcut { sequence:"Escape";enabled:root.eligible && root.session.kind==="panel";onActivated:root.session.close("escape") }
}
