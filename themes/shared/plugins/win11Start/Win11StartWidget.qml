import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "win11-start"
    popoutWidth: 620
    popoutHeight: 660

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

    component StartLogoPill: Item {
        id: pillContent
        implicitWidth: root.barThickness
        implicitHeight: root.barThickness
        width: implicitWidth
        height: implicitHeight

        LauncherLogo {
            id: logo
            anchors.centerIn: parent
            mode: SettingsData.launcherLogoMode || "os"
            size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset || 0, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            appsIconColor: Theme.widgetIconColor
            colorOverride: Theme.effectiveLogoColor || ""
            brightness: SettingsData.launcherLogoBrightness !== undefined ? SettingsData.launcherLogoBrightness : 0.0
            contrast: SettingsData.launcherLogoContrast !== undefined ? SettingsData.launcherLogoContrast : 0.0
            customPath: SettingsData.launcherLogoCustomPath || ""
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
