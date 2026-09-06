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

    layerNamespacePlugin: "win10-clock"

    pillClickAction: (x, y, w, s, scr, barPosition, barTh, barSp, cfg) => {
        popoutService?.toggleNotificationCenter(x, y, w, s, scr || parentScreen, barPosition, barTh, barSp, cfg);
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
            implicitWidth: root.barThickness
            implicitHeight: vCol.implicitHeight + 16

            readonly property int bellSize: Theme.barIconSize(root.barThickness, -4, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
            readonly property int clockFontSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : 1, root.barConfig ? root.barConfig.maximizeWidgetText : false)

            SystemClock {
                id: vClock

                precision: SystemClock.Minutes
            }

            Column {
                id: vCol

                spacing: 2
                anchors.centerIn: parent

                DankIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "notifications"
                    filled: root.hasNotifications
                    size: bellSize
                    color: root.hasNotifications ? Theme.primary : Theme.widgetTextColor
                }

                StyledText {
                    text: vClock.date ? Qt.formatTime(vClock.date, SettingsData.use24HourClock ? "HH:mm" : "h:mm") : ""
                    font.pixelSize: clockFontSize
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: vClock.date ? Qt.formatDate(vClock.date, "dd/MM/yyyy") : ""
                    font.pixelSize: clockFontSize
                    color: Theme.widgetTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
}
