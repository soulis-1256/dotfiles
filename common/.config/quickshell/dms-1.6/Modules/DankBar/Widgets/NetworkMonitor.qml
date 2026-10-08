import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

BasePill {
    id: root

    property var widgetData: null
    property bool minimumWidth: (widgetData && widgetData.minimumWidth !== undefined) ? widgetData.minimumWidth : true

    function formatSpeedValue(bytesPerSec) {
        if (!bytesPerSec || bytesPerSec <= 0)
            return 0;
        return Math.round((bytesPerSec * 8) / 1000000);
    }

    Component.onCompleted: {
        DgopService.addRef(["network"]);
    }
    Component.onDestruction: {
        DgopService.removeRef(["network"]);
    }

    content: Component {
        Item {
            property bool showingDown: true
            property Item activeArrow: root.isVerticalOrientation ? vArrow : hArrow
            property Item activeNumber: root.isVerticalOrientation ? vValue : hValue

            function swapReadout() {
                swapPhaseA.stop();
                swapPhaseB.stop();
                hArrow.rotation = 0;
                vArrow.rotation = 0;
                hValue.opacity = 1;
                vValue.opacity = 1;
                outOp.target = activeNumber;
                spinAnim.target = activeArrow;
                inOp.target = activeNumber;
                swapPhaseA.start();
            }

            Timer {
                interval: 2500
                repeat: true
                running: true
                onTriggered: swapReadout()
            }

            ParallelAnimation {
                id: swapPhaseA
                NumberAnimation { id: outOp; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
                NumberAnimation { id: spinAnim; property: "rotation"; from: 0; to: 180; duration: 240; easing.type: Easing.InOutCubic }
                onFinished: {
                    showingDown = !showingDown;
                    hArrow.rotation = 0;
                    vArrow.rotation = 0;
                    swapPhaseB.start();
                }
            }

            ParallelAnimation {
                id: swapPhaseB
                NumberAnimation { id: inOp; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }

            implicitWidth: root.isVerticalOrientation ? (root.widgetThickness - root.horizontalPadding * 2) : contentRow.implicitWidth
            implicitHeight: root.isVerticalOrientation ? contentColumn.implicitHeight : (root.widgetThickness - root.horizontalPadding * 2)

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: 1
                visible: root.isVerticalOrientation

                Row {
                    id: vSlot
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXXS

                    DankIcon {
                        id: vArrow
                        name: showingDown ? "arrow_downward" : "arrow_upward"
                        size: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        transformOrigin: Item.Center
                    }

                    StyledText {
                        id: vValue
                        text: showingDown ? Math.round((DgopService.networkRxRate * 8) / 1000000) : Math.round((DgopService.networkTxRate * 8) / 1000000)
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        elide: Text.ElideNone
                        wrapMode: Text.NoWrap
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "M"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                visible: !root.isVerticalOrientation

                StyledTextMetrics {
                    id: speedBaseline
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    text: "999"
                }

                Row {
                    id: hSlot
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    DankIcon {
                        id: hArrow
                        name: showingDown ? "arrow_downward" : "arrow_upward"
                        size: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        transformOrigin: Item.Center
                    }

                    Item {
                        implicitWidth: root.minimumWidth ? Math.max(speedBaseline.width, hValue.implicitWidth) : hValue.implicitWidth
                        implicitHeight: hValue.implicitHeight
                        width: implicitWidth
                        height: implicitHeight

                        StyledText {
                            id: hValue
                            text: showingDown ? root.formatSpeedValue(DgopService.networkRxRate) : root.formatSpeedValue(DgopService.networkTxRate)
                            font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                            color: Theme.widgetTextColor
                            elide: Text.ElideNone
                            wrapMode: Text.NoWrap
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    StyledText {
                        text: "Mbps"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }
    }
}
