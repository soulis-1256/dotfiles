import QtQuick
import Quickshell.Hyprland
import qs.Common

// Delays grab release so keyboardFocus=None commits before the grab dies,
// keeping Hyprland from handing focus back to the closing surface (#2577)
HyprlandFocusGrab {
    id: root

    property bool wanted: false
    property var clientWindows: []
    property bool _held: false
    property bool _compositorCleared: false
    property var _restoreToplevel: null

    // Other-monitor dismiss overlays must stay whitelisted. A click on a
    // non-whitelisted surface clears the compositor grab and writes active=false,
    // which breaks a QML binding and prevents the next open from re-acquiring.
    windows: (clientWindows || []).concat(KeyboardFocus.dismissWindows)

    property Timer _releaseTimer: Timer {
        interval: 50
        onTriggered: {
            root._held = false;
            root.active = false;
            root._restoreToplevel = root._compositorCleared ? null : KeyboardFocus.restoreToplevel(root._restoreToplevel);
        }
    }

    onWantedChanged: _sync()
    Component.onCompleted: _sync()

    function _sync() {
        if (!wanted) {
            if (_held)
                _releaseTimer.restart();
            return;
        }
        _releaseTimer.stop();
        _held = true;
        _compositorCleared = false;
        _restoreToplevel = KeyboardFocus.captureActiveToplevel();
        active = true;
    }

    onCleared: {
        _compositorCleared = true;
        DismissCatcher.dismiss();
    }
}
