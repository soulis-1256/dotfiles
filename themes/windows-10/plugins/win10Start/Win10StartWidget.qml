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

    layerNamespacePlugin: "win10-start"
    pillHorizontalPadding: 0
    popoutWidth: 948
    popoutHeight: 620
    popoutFlush: true
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
                mode: SettingsData.launcherLogoMode
                size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconColor: Theme.widgetIconColor
                colorOverride: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
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
                mode: SettingsData.launcherLogoMode
                size: Theme.barIconSize(root.barThickness, SettingsData.launcherLogoSizeOffset, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                appsIconColor: Theme.widgetIconColor
                colorOverride: Theme.effectiveLogoColor
                brightness: SettingsData.launcherLogoBrightness
                contrast: SettingsData.launcherLogoContrast
                customPath: SettingsData.launcherLogoCustomPath
            }
        }
    }

    popoutContent: Component {
        StartMenu {}
    }
}
