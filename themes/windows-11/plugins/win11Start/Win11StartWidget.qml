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

    function toggleWithMode(mode) {
        root.triggerPopout();
    }

    function openWithMode(mode) {
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

    horizontalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: root.barThickness
            width: implicitWidth
            height: implicitHeight

            LauncherLogo {
                anchors.centerIn: parent
                barThickness: root.barThickness
                barConfig: root.barConfig
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: root.barThickness
            implicitHeight: root.barThickness
            width: implicitWidth
            height: implicitHeight

            LauncherLogo {
                anchors.centerIn: parent
                barThickness: root.barThickness
                barConfig: root.barConfig
            }
        }
    }

    popoutContent: Component {
        StartMenu {}
    }
}
