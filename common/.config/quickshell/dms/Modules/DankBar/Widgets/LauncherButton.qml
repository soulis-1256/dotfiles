import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property bool isActive: false
    property var hyprlandOverviewLoader: null

    content: Component {
        Item {
            implicitWidth: root.widgetThickness - root.horizontalPadding * 2
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2

            LauncherLogo {
                anchors.centerIn: parent
                barThickness: root.barThickness
                barConfig: root.barConfig
            }
        }
    }

    onRightClicked: {
        if (CompositorService.isNiri) {
            NiriService.toggleOverview();
        } else if (root.hyprlandOverviewLoader?.item) {
            root.hyprlandOverviewLoader.item.overviewOpen = !root.hyprlandOverviewLoader.item.overviewOpen;
        }
    }
}
