import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true

    function formatNetworkSpeed(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0)
            return "0 Mbps";
        const mbps = Math.round((bytesPerSec * 8) / 1000000);
        return mbps + " Mbps";
    }

    Component.onCompleted: {
        DgopService.addRef(["network"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["network"]);
    }

    content: Component {
        Item {
            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: Theme.spacingXXS
                visible: root.isVerticalOrientation

                StyledText {
                    text: Math.round((DgopService.networkRxRate * 8) / 1000000) + "M"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.info
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: Math.round((DgopService.networkTxRate * 8) / 1000000) + "M"
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingM
                visible: !root.isVerticalOrientation

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    StyledText {
                        text: "↓"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.info
                    }

                    StyledText {
                        id: rxText
                        text: root.formatNetworkSpeed(DgopService.networkRxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    StyledText {
                        text: "↑"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.error
                    }

                    StyledText {
                        id: txText
                        text: root.formatNetworkSpeed(DgopService.networkTxRate)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                    }
                }
            }
        }
    }
}
