import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    readonly property var log: Log.scoped("GameOverlay")
    property var popoutService: null
    readonly property var cc: PopoutService.controlCenterPopout

    onCcChanged: hookControlCenter()

    function hookControlCenter() {
        if (!cc)
            return;

        // Fullscreen games keep an active pointer constraint that Hyprland will not
        // hit-test overlays against. Exclusive keyboard on both the overlay surface
        // and its backdrop drops that constraint so Control Center receives mouse focus
        // over games, and clicking outside dismisses it back to the game.
        cc.customKeyboardFocus = Qt.binding(() => {
            if (cc.anyModalOpen)
                return WlrKeyboardFocus.None;
            if (!cc.shouldBeVisible)
                return null;

            const targetScreen = cc.triggerScreen ?? cc.screen ?? CompositorService.getFocusedScreen();
            const screenName = targetScreen ? (targetScreen.name ?? "") : "";

            let hasFullscreen = false;
            if (typeof Hyprland !== "undefined" && Hyprland.toplevels?.values) {
                for (const t of Hyprland.toplevels.values) {
                    const monName = t.monitor?.name ?? t.lastIpcObject?.monitor ?? "";
                    if (screenName && monName && monName !== screenName)
                        continue;
                    const fs = t.lastIpcObject?.fullscreen;
                    const fsc = t.lastIpcObject?.fullscreenClient;
                    if (fs === 2 || fs === 3 || fs === true || fsc === 2 || fsc === 3) {
                        hasFullscreen = true;
                        break;
                    }
                }
            } else if (typeof CompositorService !== "undefined" && CompositorService.fullscreenToplevelOnScreen) {
                hasFullscreen = CompositorService.fullscreenToplevelOnScreen(targetScreen);
            }

            return hasFullscreen ? WlrKeyboardFocus.Exclusive : null;
        });
    }

    Connections {
        target: PopoutService
        function onControlCenterPopoutChanged() {
            root.hookControlCenter();
        }
    }

    // Hyprland routes all pointer motion to Exclusive surfaces. When the popout
    // is in Exclusive mode over a fullscreen game, its backgroundWindow must also
    // request Exclusive or clicks outside the panel will be dropped instead of dismissing.
    Binding {
        target: cc ? cc.backgroundWindow : null
        property: "WlrLayershell.keyboardFocus"
        value: (cc && cc.customKeyboardFocus === WlrKeyboardFocus.Exclusive) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        when: cc !== null && cc.shouldBeVisible
    }

    Component.onCompleted: {
        if (PopoutService.controlCenterLoader && !PopoutService.controlCenterLoader.active) {
            PopoutService.controlCenterLoader.active = true;
        }
        root.hookControlCenter();
    }
}
