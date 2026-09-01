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
}
