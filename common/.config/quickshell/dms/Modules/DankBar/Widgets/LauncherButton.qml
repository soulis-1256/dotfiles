import QtQuick
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
            implicitWidth: logo.implicitWidth
            implicitHeight: root.widgetThickness - root.horizontalPadding * 2
            width: implicitWidth
            height: implicitHeight

            LauncherLogo {
                id: logo
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
