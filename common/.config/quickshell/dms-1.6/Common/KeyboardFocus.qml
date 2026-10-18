pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Services

// Manages keyboard focus policy for popouts, modals, and Hyprland focus grabs
Singleton {
    id: root

    function keyboardFocus(active, customFocus) {
        if (PopoutManager.screenshotActive)
            return WlrKeyboardFocus.None;
        if (customFocus !== null && customFocus !== undefined)
            return customFocus;
        if (!active)
            return WlrKeyboardFocus.None;
        if (CompositorService.useHyprlandFocusGrab)
            return WlrKeyboardFocus.OnDemand;
        return WlrKeyboardFocus.Exclusive;
    }

    function wantsGrab(active, customFocus) {
        return CompositorService.useHyprlandFocusGrab && keyboardFocus(active, customFocus) === WlrKeyboardFocus.OnDemand;
    }

    function captureActiveToplevel() {
        const toplevel = ToplevelManager.activeToplevel;
        let wsId = null;
        if (CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
            wsId = Hyprland.focusedWorkspace.id;
        }
        return {
            toplevel: toplevel,
            workspaceId: wsId
        };
    }

    function restoreToplevel(saved) {
        if (!saved)
            return null;
        const toplevel = (saved.toplevel !== undefined) ? saved.toplevel : saved;
        const initialWsId = saved.workspaceId;

        if (CompositorService.isHyprland && typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
            const currentWsId = Hyprland.focusedWorkspace.id;
            // If the user switched workspace while the widget/grab was active,
            // DO NOT restore focus to the old toplevel, because doing so causes
            // Hyprland to yank the user back to the previous workspace.
            if (initialWsId !== null && initialWsId !== undefined && currentWsId !== initialWsId) {
                Qt.callLater(() => {
                    HyprlandService.focusWorkspace(currentWsId);
                });
                return null;
            }
        }

        if (toplevel)
            Qt.callLater(() => toplevel.activate());
        return null;
    }

    property list<var> barWindows: []
    property list<var> dismissWindows: []

    function registerBarWindow(window) {
        if (!window || barWindows.indexOf(window) !== -1)
            return;
        barWindows = barWindows.concat([window]);
    }

    function unregisterBarWindow(window) {
        const idx = barWindows.indexOf(window);
        if (idx === -1)
            return;
        const next = barWindows.slice();
        next.splice(idx, 1);
        barWindows = next;
    }

    function registerDismissWindow(window) {
        if (!window || dismissWindows.indexOf(window) !== -1)
            return;
        dismissWindows = dismissWindows.concat([window]);
    }

    function unregisterDismissWindow(window) {
        const idx = dismissWindows.indexOf(window);
        if (idx === -1)
            return;
        const next = dismissWindows.slice();
        next.splice(idx, 1);
        dismissWindows = next;
    }

    // True when item is the key target, or a FocusScope ancestor of it.
    function focusWithin(item) {
        if (!item)
            return false;
        let focused = null;
        try {
            focused = item.Window.window ? item.Window.window.activeFocusItem : null;
        } catch (e) {
            return false;
        }
        while (focused) {
            if (focused === item)
                return true;
            focused = focused.parent;
        }
        return false;
    }

    function focusItem(item) {
        if (!item || focusWithin(item))
            return;
        item.forceActiveFocus();
    }

    // Repeat until the window is actually active. forceActiveFocus during
    // open often runs before the layer can receive keys, and the sibling
    // Escape scope then keeps Enter.
    property var _focusSoonItem: null
    property int _focusSoonTries: 0

    function cancelFocusSoon(item) {
        if (item && root._focusSoonItem !== item)
            return;
        _focusSoonItem = null;
        _focusSoonTries = 0;
        _focusSoonTimer.stop();
    }

    function focusSoon(item) {
        if (!item)
            return;
        _focusSoonItem = item;
        _focusSoonTries = 0;
        focusItem(item);
        _focusSoonTimer.restart();
    }

    Timer {
        id: _focusSoonTimer
        interval: 40
        repeat: true
        onTriggered: {
            const item = root._focusSoonItem;
            if (!item) {
                stop();
                return;
            }
            let win = null;
            let focused = null;
            try {
                win = item.Window.window;
                focused = win ? win.activeFocusItem : null;
            } catch (e) {
                stop();
                return;
            }
            // A text field (or anything outside the target) took the chain.
            if (focused && focused !== item && !root.focusWithin(item)) {
                stop();
                return;
            }
            root.focusItem(item);
            root._focusSoonTries += 1;
            if ((win && win.active && root.focusWithin(item)) || root._focusSoonTries >= 8)
                stop();
        }
    }
}
