import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.DCommon.Widgets
import qs.Widgets

PluginComponent {
    id: root

    layerNamespacePlugin: "alternating-network"

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

    horizontalBarPill: Component {
        Item {
            property bool showingDown: true

            function swapReadout() {
                swapPhaseA.stop();
                swapPhaseB.stop();
                hArrow.rotation = 0;
                hValue.opacity = 1;
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
                NumberAnimation { target: hValue; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
                NumberAnimation { target: hArrow; property: "rotation"; from: 0; to: 180; duration: 240; easing.type: Easing.InOutCubic }
                onFinished: {
                    showingDown = !showingDown;
                    hArrow.rotation = 0;
                    swapPhaseB.start();
                }
            }

            ParallelAnimation {
                id: swapPhaseB
                NumberAnimation { target: hValue; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }

            implicitWidth: contentRow.implicitWidth
            implicitHeight: root.widgetThickness

            Row {
                id: contentRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                StyledTextMetrics {
                    id: speedBaseline
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                    text: "999"
                }

                Row {
                    id: hSlot
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingXXS

                    DIcon {
                        id: hArrow
                        name: showingDown ? "arrow_downward" : "arrow_upward"
                        size: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        transformOrigin: Item.Center
                    }

                    Item {
                        implicitWidth: Math.max(speedBaseline.width, hValue.implicitWidth)
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

    verticalBarPill: Component {
        Item {
            property bool showingDown: true

            function swapReadout() {
                swapPhaseAVert.stop();
                swapPhaseBVert.stop();
                vArrow.rotation = 0;
                vValue.opacity = 1;
                swapPhaseAVert.start();
            }

            Timer {
                interval: 2500
                repeat: true
                running: true
                onTriggered: swapReadout()
            }

            ParallelAnimation {
                id: swapPhaseAVert
                NumberAnimation { target: vValue; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InCubic }
                NumberAnimation { target: vArrow; property: "rotation"; from: 0; to: 180; duration: 240; easing.type: Easing.InOutCubic }
                onFinished: {
                    showingDown = !showingDown;
                    vArrow.rotation = 0;
                    swapPhaseBVert.start();
                }
            }

            ParallelAnimation {
                id: swapPhaseBVert
                NumberAnimation { target: vValue; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
            }

            implicitWidth: root.widgetThickness
            implicitHeight: contentColumn.implicitHeight

            Column {
                id: contentColumn
                anchors.centerIn: parent
                spacing: 1

                Row {
                    id: vSlot
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingXXS

                    DIcon {
                        id: vArrow
                        name: showingDown ? "arrow_downward" : "arrow_upward"
                        size: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
                        color: Theme.widgetTextColor
                        anchors.verticalCenter: parent.verticalCenter
                        transformOrigin: Item.Center
                    }

                    StyledText {
                        id: vValue
                        text: showingDown ? root.formatSpeedValue(DgopService.networkRxRate) : root.formatSpeedValue(DgopService.networkTxRate)
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
        }
    }
}
