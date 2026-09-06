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
        if (bytesPerSec < 1024) {
            return bytesPerSec.toFixed(0) + " B/s";
        } else if (bytesPerSec < 1024 * 1024) {
            return (bytesPerSec / 1024).toFixed(1) + " KB/s";
        } else if (bytesPerSec < 1024 * 1024 * 1024) {
            return (bytesPerSec / (1024 * 1024)).toFixed(1) + " MB/s";
        } else {
            return (bytesPerSec / (1024 * 1024 * 1024)).toFixed(1) + " GB/s";
        }
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

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const rate = DgopService.networkRxRate;
                        if (rate < 1024)
                            return rate.toFixed(0);
                        if (rate < 1024 * 1024)
                            return (rate / 1024).toFixed(0) + "K";
                        return (rate / (1024 * 1024)).toFixed(0) + "M";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.info
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: {
                        const rate = DgopService.networkTxRate;
                        if (rate < 1024)
                            return rate.toFixed(0);
                        if (rate < 1024 * 1024)
                            return (rate / 1024).toFixed(0) + "K";
                        return (rate / (1024 * 1024)).toFixed(0) + "M";
                    }
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    color: Theme.error
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingS
                visible: !root.isVerticalOrientation

                DankIcon {
                    name: "network_check"
                    size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
                    color: Theme.widgetTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "↓"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.info
                    }

                    Item {
                        id: rxBox
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: root.minimumWidth ? Math.max(rxBaseline.width, rxText.paintedWidth) : rxText.paintedWidth
                        implicitHeight: rxText.implicitHeight
                        width: implicitWidth
                        height: implicitHeight

                        StyledTextMetrics {
                            id: rxBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            text: "999.9 MB/s"
                        }

                        StyledText {
                            id: rxText
                            text: DgopService.networkRxRate > 0 ? root.formatNetworkSpeed(DgopService.networkRxRate) : "0 B/s"
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            color: Theme.widgetTextColor
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap
                        }
                    }
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXS

                    StyledText {
                        text: "↑"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.error
                    }

                    Item {
                        id: txBox
                        anchors.verticalCenter: parent.verticalCenter
                        implicitWidth: root.minimumWidth ? Math.max(txBaseline.width, txText.paintedWidth) : txText.paintedWidth
                        implicitHeight: txText.implicitHeight
                        width: implicitWidth
                        height: implicitHeight

                        StyledTextMetrics {
                            id: txBaseline
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            text: "999.9 MB/s"
                        }

                        StyledText {
                            id: txText
                            text: DgopService.networkTxRate > 0 ? root.formatNetworkSpeed(DgopService.networkTxRate) : "0 B/s"
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            color: Theme.widgetTextColor
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap
                        }
                    }
                }
            }
        }
    }
}
