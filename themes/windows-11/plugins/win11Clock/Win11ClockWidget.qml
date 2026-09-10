import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    property var popoutService: null
    readonly property bool hasNotifications: NotificationService.notifications.length > 0

    layerNamespacePlugin: "win11-clock"
    pillHorizontalPadding: 0

    pillClickAction: (x, y, w, s, scr, barPosition, barTh, barSp, cfg) => {
        (popoutService || PopoutService).toggleNotificationCenter(x, y, w, s, scr || parentScreen, barPosition, barTh, barSp, cfg);
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: clockRow.implicitWidth + 16
            implicitHeight: root.barThickness

            readonly property int bellSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            readonly property int clockFontSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)
            readonly property real clockTextWidth: Math.max(timeLabel.implicitWidth, dateLabel.implicitWidth)

            SystemClock {
                id: systemClock

                precision: SettingsData.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
            }

            Row {
                id: clockRow

                spacing: 8
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 8

                Column {
                    id: clockCol

                    spacing: 0
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        id: timeLabel
                        width: clockTextWidth
                        text: {
                            const d = systemClock.date;
                            if (!d)
                                return "";

                            if (SettingsData.use24HourClock)
                                return Qt.formatTime(d, SettingsData.showSeconds ? "HH:mm:ss" : "HH:mm");

                            return Qt.formatTime(d, SettingsData.showSeconds ? "h:mm:ss AP" : "h:mm AP");
                        }
                        font.pixelSize: clockFontSize
                        color: Theme.widgetTextColor
                        horizontalAlignment: Text.AlignRight
                    }

                    StyledText {
                        id: dateLabel
                        width: clockTextWidth
                        text: systemClock.date ? Qt.formatDate(systemClock.date, "dd/MM/yyyy") : ""
                        font.pixelSize: clockFontSize
                        color: Theme.widgetTextColor
                        horizontalAlignment: Text.AlignRight
                    }
                }

                Item {
                    width: bellSize
                    height: Math.max(bellSize, clockCol.implicitHeight)
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "notifications"
                        filled: root.hasNotifications
                        size: bellSize
                        color: root.hasNotifications ? Theme.primary : Theme.widgetTextColor
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            id: vRoot

            implicitWidth: root.barThickness
            implicitHeight: vCol.implicitHeight + 16

            readonly property int bellSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            readonly property int clockFontSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)
            readonly property int digitWidth: Math.round(clockFontSize * 0.6)

            SystemClock {
                id: vClock

                precision: SystemClock.Minutes
            }

            function twoDigits(value) {
                return String(value).padStart(2, "0");
            }

            readonly property var stackedDigits: {
                const d = vClock.date;
                if (!d)
                    return ["00", "00", "00", "00", "00"];
                let hours = d.getHours();
                if (!SettingsData.use24HourClock)
                    hours = hours === 0 ? 12 : hours > 12 ? hours - 12 : hours;
                return [
                    twoDigits(hours),
                    twoDigits(d.getMinutes()),
                    twoDigits(d.getDate()),
                    twoDigits(d.getMonth() + 1),
                    String(d.getFullYear()).slice(-2)
                ];
            }

            Column {
                id: vCol

                spacing: 0
                anchors.centerIn: parent
                width: parent.width

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "notifications"
                    filled: root.hasNotifications
                    size: Math.min(bellSize, parent.width - 4)
                    color: root.hasNotifications ? Theme.primary : Theme.widgetTextColor
                }

                Item {
                    width: parent.width
                    height: Theme.spacingXS
                }

                Repeater {
                    model: 5

                    Column {
                        required property int index
                        width: vCol.width
                        spacing: 0

                        Item {
                            width: parent.width
                            height: Theme.spacingS
                            visible: index === 2

                            Rectangle {
                                width: parent.width * 0.45
                                height: 1
                                color: Theme.outlineButton
                                anchors.centerIn: parent
                            }
                        }

                        Row {
                            spacing: 0
                            anchors.horizontalCenter: parent.horizontalCenter

                            StyledText {
                                text: vRoot.stackedDigits[index].charAt(0)
                                width: digitWidth
                                font.pixelSize: clockFontSize
                                color: Theme.widgetTextColor
                                horizontalAlignment: Text.AlignHCenter
                            }

                            StyledText {
                                text: vRoot.stackedDigits[index].charAt(1)
                                width: digitWidth
                                font.pixelSize: clockFontSize
                                color: Theme.widgetTextColor
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
