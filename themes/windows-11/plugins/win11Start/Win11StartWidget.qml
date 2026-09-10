import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    pillRightClickAction: () => {
        if (CompositorService.isNiri) {
            NiriService.toggleOverview();
        } else if (root.blurBarWindow?.hyprlandOverviewLoader?.item) {
            const ov = root.blurBarWindow.hyprlandOverviewLoader.item;
            ov.overviewOpen = !ov.overviewOpen;
        } else {
            Quickshell.process(["dms", "ipc", "call", "hypr", "toggleOverview"]);
        }
    }

    function registerAsLauncher() {
        if (root.blurBarWindow)
            root.blurBarWindow.launcherButtonRef = root;
    }

    signal triggerPulse()

    function toggleWithMode(mode) {
        root.triggerPulse();
        root.triggerPopout();
    }

    function openWithMode(mode) {
        root.triggerPulse();
        root.triggerPopout();
    }

    layerNamespacePlugin: "win11-start"
    pillHorizontalPadding: 0
    popoutWidth: 648
    popoutHeight: 672
    popoutFlush: true
    popoutPositioning: section === "center" ? "screen" : ""
    Component.onCompleted: registerAsLauncher()
    onBlurBarWindowChanged: registerAsLauncher()
    Component.onDestruction: {
        if (root.blurBarWindow && root.blurBarWindow.launcherButtonRef === root)
            root.blurBarWindow.launcherButtonRef = null;
    }

    component StartLogoPill: Item {
        id: pillContent
        implicitWidth: root.barThickness
        implicitHeight: root.barThickness
        width: implicitWidth
        height: implicitHeight

        property real currentScale: 1.0

        NumberAnimation {
            id: pressAnim
            target: pillContent
            property: "currentScale"
            to: 0.86
            duration: 70
            easing.type: Easing.OutQuad
        }

        NumberAnimation {
            id: releaseAnim
            target: pillContent
            property: "currentScale"
            from: Math.min(pillContent.currentScale, 0.86)
            to: 1.0
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.5
        }

        SequentialAnimation {
            id: pulseAnim
            NumberAnimation {
                target: pillContent
                property: "currentScale"
                to: 0.86
                duration: 70
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: pillContent
                property: "currentScale"
                to: 1.0
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.5
            }
        }

        Connections {
            target: root
            function onIsPressedChanged() {
                if (root.isPressed) {
                    releaseAnim.stop();
                    pulseAnim.stop();
                    pressAnim.restart();
                } else {
                    pressAnim.stop();
                    releaseAnim.restart();
                }
            }
            function onTriggerPulse() {
                pressAnim.stop();
                releaseAnim.stop();
                pulseAnim.restart();
            }
        }

        LauncherLogo {
            id: logo
            anchors.centerIn: parent
            barThickness: root.barThickness
            barConfig: root.barConfig
            scale: pillContent.currentScale
            transformOrigin: Item.Center
        }
    }

    horizontalBarPill: Component {
        StartLogoPill {}
    }

    verticalBarPill: Component {
        StartLogoPill {}
    }

    popoutContent: Component {
        StartMenu {}
    }
}
