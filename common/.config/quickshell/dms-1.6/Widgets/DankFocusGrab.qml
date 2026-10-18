import QtQuick
import Quickshell.Hyprland
import qs.Common

// Delays grab release so keyboardFocus=None commits before the grab dies,
// keeping Hyprland from handing focus back to the closing surface (#2577)
HyprlandFocusGrab {
    id: root

    property bool wanted: false
    // The notepad slideout stays open across window clicks, so restoring the
    // toplevel captured when the grab started would pull focus back off the
    // window the user just clicked.
    property bool restoreFocus: true
    property var clientWindows: []
    property bool _held: false
    property bool _compositorCleared: false
    property var _restoreToplevel: null
    property int _restoreWorkspaceId: -1
    property int _armTries: 0
    // Modals and menus that don't run their own settle loop set this. A grab
    // started in the same turn the surface maps is often cleared, and a bare
    // active=true afterwards is ignored while targetActive is still true.
    property bool retryStartup: false
    // Hyprland keyboard-focuses the first whitelist surface under the pointer
    // when the grab starts, otherwise the first surface. A fullscreen dismiss
    // layer is keyboard None, so the pointer sitting on another monitor
    // swallows Escape and Enter until the pointer enters the menu. The first
    // commit is clientWindows only. Dismiss layers join once `active` is true,
    // and that add does not move the keyboard.
    property bool deferDismissWindows: true

    // The seat keyboard is on this grab. Content should take Qt focus now.
    signal keyboardGrabbed

    windows: {
        const clients = clientWindows || [];
        if (root.deferDismissWindows && !root.active)
            return clients;
        return clients.concat(KeyboardFocus.dismissWindows);
    }

    property Timer _releaseTimer: Timer {
        interval: 50
        onTriggered: {
            root._held = false;
            root.active = false;
            // Restoring a toplevel from another workspace would drag the user back
            // to the workspace they just navigated away from (#2963)
            const workspaceChanged = (Hyprland.focusedWorkspace?.id ?? -1) !== root._restoreWorkspaceId;
            root._restoreToplevel = (root.restoreFocus && !root._compositorCleared && !workspaceChanged) ? KeyboardFocus.restoreToplevel(root._restoreToplevel) : null;
        }
    }

    // HyprlandFocusGrab is not an Item and has no default property. A bare
    // child Timer makes the type fail to load, which unloads the bar.
    property Timer armTimer: Timer {
        interval: 0
        onTriggered: {
            if (!root.wanted)
                return;
            // Callers such as DankPopout activate in the same turn. Setting
            // active again would rebuild the grab and rerun the pointer search.
            if (!root.active)
                root.active = true;
            if (root.retryStartup)
                settleTimer.restart();
        }
    }

    property Timer settleTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            if (!root.wanted || !root.retryStartup)
                return;
            if (root.active)
                return;
            if (root._armTries >= 4)
                return;
            root._armTries += 1;
            root._compositorCleared = false;
            root.active = false;
            root.active = true;
            settleTimer.restart();
        }
    }

    onWantedChanged: _sync()
    Component.onCompleted: _sync()
    onActiveChanged: {
        if (!root.active)
            return;
        Qt.callLater(() => {
            if (root.active)
                root.keyboardGrabbed();
        });
    }

    function _sync() {
        if (!wanted) {
            root._armTries = 0;
            armTimer.stop();
            settleTimer.stop();
            if (_held)
                _releaseTimer.restart();
            return;
        }
        _releaseTimer.stop();
        _held = true;
        _compositorCleared = false;
        _restoreToplevel = KeyboardFocus.captureActiveToplevel();
        _restoreWorkspaceId = Hyprland.focusedWorkspace?.id ?? -1;
        root._armTries = 0;
        // Next turn, so an OnDemand commit queued with this open is already
        // in flight before Hyprland refocuses the whitelist.
        armTimer.restart();
    }

    // Nested surfaces (power menu) clear this grab; dismiss is owned by
    // DismissCatcherWindow so stacked dialogs are not closed with the parent.
    onCleared: _compositorCleared = true
}
